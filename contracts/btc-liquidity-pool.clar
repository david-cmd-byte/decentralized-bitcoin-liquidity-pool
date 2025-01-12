;; Title: Decentralized Bitcoin Liquidity Pool (DLBP)

;; Summary:
;; A decentralized liquidity pool for Bitcoin that enables users to deposit BTC,
;; earn yield, and withdraw funds. The contract implements deposit/withdrawal mechanisms,
;; yield calculation, and administrative controls with safety measures.

;; Constants

(define-constant contract-owner tx-sender)

;; Error Codes
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-pool-inactive (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-pool-full (err u106))
(define-constant err-invalid-bool (err u107))

;; State Variables

(define-data-var total-liquidity uint u0)
(define-data-var pool-active bool true)
(define-data-var min-deposit uint u1000000)         ;; 0.01 BTC in sats
(define-data-var max-pool-size uint u100000000000)  ;; 1000 BTC in sats
(define-data-var yield-rate uint u500)              ;; 5% APY in basis points
(define-data-var last-yield-calculation uint block-height)

;; Data Maps

(define-map user-deposits
    principal
    {
        amount: uint,
        last-deposit-height: uint,
        accumulated-yield: uint
    })

(define-map yield-snapshots
    uint  ;; block height
    uint  ;; yield rate at that height
)

;; Private Functions

(define-private (calculate-yield (amount uint) (blocks uint))
    (let (
        (rate (var-get yield-rate))
        (blocks-per-year u52560)  ;; ~10 min block time
        (yield-amount (/ (* amount (* rate blocks)) (* blocks-per-year u10000)))
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
            accumulated-yield: (+ (get accumulated-yield user-data) new-yield)
        })
    (ok true)))

(define-private (validate-bool (value bool))
    (if value
        (ok true)
        (err err-invalid-bool)))

;; Public Functions

;; Deposit Function
(define-public (deposit (amount uint))
    (let (
        (user tx-sender)
        (current-liquidity (var-get total-liquidity))
        (new-liquidity (+ current-liquidity amount))
    )
    (asserts! (var-get pool-active) err-pool-inactive)
    (asserts! (>= amount (var-get min-deposit)) err-invalid-amount)
    (asserts! (<= new-liquidity (var-get max-pool-size)) err-pool-full)
    
    (match (map-get? user-deposits user)
        existing-deposit (begin
            (try! (update-user-yield user))
            (map-set user-deposits
                user
                {
                    amount: (+ amount (get amount existing-deposit)),
                    last-deposit-height: block-height,
                    accumulated-yield: (get accumulated-yield existing-deposit)
                }))
        (map-set user-deposits
            user
            {
                amount: amount,
                last-deposit-height: block-height,
                accumulated-yield: u0
            }))
    
    (var-set total-liquidity new-liquidity)
    (ok true)))

;; Withdrawal Function
(define-public (withdraw (amount uint))
    (let (
        (user tx-sender)
        (user-data (unwrap! (map-get? user-deposits user) err-not-found))
        (current-balance (get amount user-data))
    )
        (asserts! (var-get pool-active) err-pool-inactive)
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
                    accumulated-yield: (get accumulated-yield updated-data)
                })
            
            (var-set total-liquidity (- (var-get total-liquidity) amount))
            (ok true))))

;; Yield Claiming
(define-public (claim-yield)
    (let (
        (user tx-sender)
        (user-data (unwrap! (map-get? user-deposits user) err-not-found))
    )
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
                    accumulated-yield: u0
                })
            (ok yield-to-claim))))

;; Read-only Functions

(define-read-only (get-user-position (user principal))
    (map-get? user-deposits user))

(define-read-only (get-pool-stats)
    {
        total-liquidity: (var-get total-liquidity),
        pool-active: (var-get pool-active),
        current-yield-rate: (var-get yield-rate),
        min-deposit: (var-get min-deposit),
        max-pool-size: (var-get max-pool-size)
    })
