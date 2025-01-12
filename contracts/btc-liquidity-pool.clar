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