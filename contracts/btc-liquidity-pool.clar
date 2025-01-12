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