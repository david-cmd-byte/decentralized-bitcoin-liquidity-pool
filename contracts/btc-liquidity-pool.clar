;; Title: Decentralized Bitcoin Liquidity Pool (DLBP)

;; Summary:
;; A decentralized liquidity pool for Bitcoin that enables users to deposit BTC,
;; earn yield, and withdraw funds. The contract implements deposit/withdrawal mechanisms,
;; yield calculation, and administrative controls with safety measures.

;; Constants

(define-constant contract-owner tx-sender)
(define-constant blocks-per-year u52560)  ;; Assuming ~10 min block time
(define-constant basis-points-denominator u10000)
(define-constant emergency-cooldown-period u144)  ;; 24 hours in blocks

;; Error Codes
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-pool-inactive (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-pool-full (err u106))
(define-constant err-invalid-bool (err u107))
(define-constant err-cooldown-active (err u108))
(define-constant err-below-min-deposit (err u109))
(define-constant err-above-max-deposit (err u110))
(define-constant err-paused (err u111))

;; State Variables

(define-data-var total-liquidity uint u0)
(define-data-var pool-active bool true)
(define-data-var emergency-paused bool false)
(define-data-var min-deposit uint u1000000)         ;; 0.01 BTC in sats
(define-data-var max-deposit-per-user uint u1000000000)  ;; 10 BTC in sats
(define-data-var max-pool-size uint u100000000000)  ;; 1000 BTC in sats
(define-data-var yield-rate uint u500)              ;; 5% APY in basis points
(define-data-var last-yield-calculation uint block-height)
(define-data-var total-yield-paid uint u0)
(define-data-var last-emergency-action uint u0)

;; Data Maps

(define-map user-deposits
    principal
    {
        amount: uint,
        last-deposit-height: uint,
        accumulated-yield: uint,
        last-action-height: uint,
        total-deposits: uint,
        total-withdrawals: uint
    })

(define-map yield-snapshots
    uint  ;; block height
    {
        rate: uint,
        total-liquidity: uint,
        timestamp: uint
    })

(define-map authorized-operators
    principal
    bool)

;; Events

(define-data-var event-counter uint u0)

(define-map events
    uint
    {
        event-type: (string-ascii 20),
        user: principal,
        amount: uint,
        block-height: uint
    })

;; Private Functions

(define-private (log-event (event-type (string-ascii 20)) (user principal) (amount uint))
    (let ((counter (var-get event-counter)))
        (map-set events counter
            {
                event-type: event-type,
                user: user,
                amount: amount,
                block-height: block-height
            })
        (var-set event-counter (+ counter u1))
        (ok true)))

(define-private (calculate-yield (amount uint) (blocks uint))
    (let (
        (rate (var-get yield-rate))
        (yield-amount (/ (* amount (* rate blocks)) (* blocks-per-year basis-points-denominator)))
    )
    yield-amount))

(define-private (update-user-yield (user principal))
    (let (
        (user-data (unwrap! (map-get? user-deposits user) (err u0)))
        (current-height block-height)
        (blocks-since-last (- current-height (get last-deposit-height user-data)))
        (new-yield (calculate-yield (get amount user-data) blocks-since-last))
    )
    (map-set user-deposits
        user
        {
            amount: (get amount user-data),
            last-deposit-height: current-height,
            accumulated-yield: (+ (get accumulated-yield user-data) new-yield),
            last-action-height: current-height,
            total-deposits: (get total-deposits user-data),
            total-withdrawals: (get total-withdrawals user-data)
        })
    (ok true)))

(define-private (check-pool-status)
    (begin
        (asserts! (var-get pool-active) err-pool-inactive)
        (asserts! (not (var-get emergency-paused)) err-paused)
        (ok true)))

(define-private (validate-deposit-amount (amount uint))
    (begin
        (asserts! (>= amount (var-get min-deposit)) err-below-min-deposit)
        (asserts! (<= (+ (var-get total-liquidity) amount) (var-get max-pool-size)) err-pool-full)
        (ok true)))

;; Public Functions

;; Deposit Function
(define-public (deposit (amount uint))
    (let (
        (user tx-sender)
        (current-liquidity (var-get total-liquidity))
        (new-liquidity (+ current-liquidity amount))
    )
    (try! (check-pool-status))
    (try! (validate-deposit-amount amount))
    
    (match (map-get? user-deposits user)
        existing-deposit 
        (let (
            (new-user-amount (+ amount (get amount existing-deposit)))
        )
            (asserts! (<= new-user-amount (var-get max-deposit-per-user)) err-above-max-deposit)
            (try! (update-user-yield user))
            (map-set user-deposits
                user
                {
                    amount: new-user-amount,
                    last-deposit-height: block-height,
                    accumulated-yield: (get accumulated-yield existing-deposit),
                    last-action-height: block-height,
                    total-deposits: (+ (get total-deposits existing-deposit) amount),
                    total-withdrawals: (get total-withdrawals existing-deposit)
                }))
        (map-set user-deposits
            user
            {
                amount: amount,
                last-deposit-height: block-height,
                accumulated-yield: u0,
                last-action-height: block-height,
                total-deposits: amount,
                total-withdrawals: u0
            }))
    
    (var-set total-liquidity new-liquidity)
    (try! (log-event "DEPOSIT" user amount))
    (ok true)))

;; Withdrawal Function
(define-public (withdraw (amount uint))
    (let (
        (user tx-sender)
        (user-data (unwrap! (map-get? user-deposits user) err-not-found))
        (current-balance (get amount user-data))
    )
        (try! (check-pool-status))
        (asserts! (<= amount current-balance) err-insufficient-balance)
        
        (try! (update-user-yield user))
        (let (
            (updated-data (unwrap! (map-get? user-deposits user) err-not-found))
            (remaining-balance (- current-balance amount))
        )
            (map-set user-deposits
                user
                {
                    amount: remaining-balance,
                    last-deposit-height: block-height,
                    accumulated-yield: (get accumulated-yield updated-data),
                    last-action-height: block-height,
                    total-deposits: (get total-deposits updated-data),
                    total-withdrawals: (+ (get total-withdrawals updated-data) amount)
                })
            
            (var-set total-liquidity (- (var-get total-liquidity) amount))
            (try! (log-event "WITHDRAW" user amount))
            (ok true))))

;; Yield Claiming
(define-public (claim-yield)
    (let (
        (user tx-sender)
        (user-data (unwrap! (map-get? user-deposits user) err-not-found))
    )
        (try! (check-pool-status))
        (try! (update-user-yield user))
        (let (
            (updated-data (unwrap! (map-get? user-deposits user) err-not-found))
            (yield-to-claim (get accumulated-yield updated-data))
        )
            (map-set user-deposits
                user
                {
                    amount: (get amount updated-data),
                    last-deposit-height: block-height,
                    accumulated-yield: u0,
                    last-action-height: block-height,
                    total-deposits: (get total-deposits updated-data),
                    total-withdrawals: (get total-withdrawals updated-data)
                })
            (var-set total-yield-paid (+ (var-get total-yield-paid) yield-to-claim))
            (try! (log-event "CLAIM" user yield-to-claim))
            (ok yield-to-claim))))

;; Read-only Functions

(define-read-only (get-user-position (user principal))
    (map-get? user-deposits user))

(define-read-only (get-pool-stats)
    {
        total-liquidity: (var-get total-liquidity),
        pool-active: (var-get pool-active),
        emergency-paused: (var-get emergency-paused),
        current-yield-rate: (var-get yield-rate),
        min-deposit: (var-get min-deposit),
        max-deposit-per-user: (var-get max-deposit-per-user),
        max-pool-size: (var-get max-pool-size),
        total-yield-paid: (var-get total-yield-paid)
    })

(define-read-only (get-event (event-id uint))
    (map-get? events event-id))

;; Administrative Functions

(define-public (set-pool-active (active bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set pool-active active)
        (try! (log-event "POOL_STATUS" contract-owner (if active u1 u0)))
        (ok true)))

(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set emergency-paused true)
        (var-set last-emergency-action block-height)
        (try! (log-event "EMERGENCY_PAUSE" contract-owner u0))
        (ok true)))

(define-public (emergency-resume)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (>= (- block-height (var-get last-emergency-action)) emergency-cooldown-period) err-cooldown-active)
        (var-set emergency-paused false)
        (try! (log-event "EMERGENCY_RESUME" contract-owner u0))
        (ok true)))

(define-public (set-yield-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate basis-points-denominator) err-invalid-amount)  ;; Max 100% APY
        (var-set yield-rate new-rate)
        (map-set yield-snapshots block-height
            {
                rate: new-rate,
                total-liquidity: (var-get total-liquidity),
                timestamp: block-height
            })
        (try! (log-event "YIELD_RATE" contract-owner new-rate))
        (ok true)))

(define-public (set-pool-parameters (new-min uint) (new-max-per-user uint) (new-max-pool uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (< new-min new-max-per-user) err-invalid-amount)
        (asserts! (< new-max-per-user new-max-pool) err-invalid-amount)
        (var-set min-deposit new-min)
        (var-set max-deposit-per-user new-max-per-user)
        (var-set max-pool-size new-max-pool)
        (try! (log-event "PARAMS_UPDATE" contract-owner u0))
        (ok true)))

(define-public (add-operator (operator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-operators operator true)
        (try! (log-event "ADD_OPERATOR" operator u0))
        (ok true)))

(define-public (remove-operator (operator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-operators operator false)
        (try! (log-event "REMOVE_OPERATOR" operator u0))
        (ok true)))