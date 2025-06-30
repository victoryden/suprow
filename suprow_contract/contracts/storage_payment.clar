;; StoragePayment Smart Contract - Enhanced Version
;; Comprehensive storage payment system with advanced features

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-payment (err u102))
(define-constant err-payment-overdue (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-already-paid (err u105))
(define-constant err-unauthorized (err u106))
(define-constant err-subscription-expired (err u107))
(define-constant err-refund-not-allowed (err u108))
(define-constant err-discount-expired (err u109))
(define-constant err-quota-exceeded (err u110))
(define-constant err-invalid-tier (err u111))
(define-constant err-contract-paused (err u112))

;; Data Variables
(define-data-var fee-per-mb uint u1000) ;; Fee per MB in microSTX
(define-data-var fee-per-file uint u500) ;; Base fee per file in microSTX
(define-data-var penalty-rate uint u10) ;; Penalty rate as percentage
(define-data-var grace-period uint u604800) ;; Grace period in seconds (7 days)
(define-data-var contract-paused bool false)
(define-data-var treasury-address principal tx-sender)
(define-data-var referral-bonus-rate uint u5) ;; 5% referral bonus
(define-data-var auto-renewal-enabled bool true)

;; Subscription Plans
(define-map subscription-plans
  (string-ascii 20) ;; plan-id
  {
    name: (string-ascii 50),
    storage-limit-gb: uint,
    file-limit: uint,
    monthly-fee: uint,
    discount-rate: uint, ;; percentage off regular fees
    active: bool
  }
)

;; User Subscriptions
(define-map user-subscriptions
  principal
  {
    plan-id: (string-ascii 20),
    start-date: uint,
    end-date: uint,
    auto-renew: bool,
    storage-used-gb: uint,
    files-count: uint,
    status: (string-ascii 20) ;; ACTIVE, EXPIRED, CANCELLED
  }
)

;; Pricing Tiers (volume discounts)
(define-map pricing-tiers
  uint ;; tier-level
  {
    min-storage-gb: uint,
    max-storage-gb: uint,
    discount-percentage: uint,
    tier-name: (string-ascii 30)
  }
)

;; Storage Fees (Enhanced)
(define-map storage-fees
  { user: principal, file-id: (string-ascii 64) }
  {
    file-size-mb: uint,
    base-fee: uint,
    size-fee: uint,
    total-fee: uint,
    discounted-fee: uint,
    due-date: uint,
    payment-status: (string-ascii 20),
    penalty-amount: uint,
    created-at: uint,
    tier-applied: uint,
    subscription-discount: uint,
    refund-eligible: bool,
    priority-level: uint ;; 1=normal, 2=priority, 3=express
  }
)

;; Payment History (Enhanced)
(define-map user-payments
  { user: principal, payment-id: uint }
  {
    file-id: (string-ascii 64),
    amount-paid: uint,
    payment-method: (string-ascii 10),
    payment-date: uint,
    transaction-id: (buff 32),
    refunded: bool,
    refund-amount: uint,
    referral-code: (optional (string-ascii 20)),
    gas-fee: uint
  }
)

;; Discount Codes
(define-map discount-codes
  (string-ascii 20) ;; code
  {
    discount-percentage: uint,
    max-uses: uint,
    current-uses: uint,
    expiry-date: uint,
    min-purchase: uint,
    active: bool,
    creator: principal
  }
)

;; Referral System
(define-map referral-codes
  (string-ascii 20) ;; referral-code
  {
    owner: principal,
    total-referrals: uint,
    total-earnings: uint,
    active: bool,
    created-at: uint
  }
)

;; User Analytics
(define-map user-analytics
  principal
  {
    total-spent: uint,
    total-files: uint,
    total-storage-gb: uint,
    referral-earnings: uint,
    subscription-months: uint,
    last-payment: uint,
    payment-streak: uint,
    tier-level: uint
  }
)

;; Bulk Operations
(define-map bulk-operations
  uint ;; operation-id
  {
    initiator: principal,
    operation-type: (string-ascii 20), ;; BULK_PAYMENT, BULK_REFUND, etc.
    total-files: uint,
    completed-files: uint,
    total-amount: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

;; Escrow for disputed payments
(define-map payment-disputes
  uint ;; dispute-id
  {
    user: principal,
    file-id: (string-ascii 64),
    amount: uint,
    reason: (string-ascii 100),
    status: (string-ascii 20), ;; PENDING, RESOLVED, REJECTED
    created-at: uint,
    resolver: (optional principal)
  }
)

;; Auto-payment settings
(define-map auto-payment-settings
  principal
  {
    enabled: bool,
    payment-method: (string-ascii 10),
    max-amount: uint,
    last-auto-payment: uint,
    failed-attempts: uint
  }
)

;; Counters
(define-data-var payment-counter uint u0)
(define-data-var dispute-counter uint u0)
(define-data-var bulk-operation-counter uint u0)

;; Supported tokens
(define-map supported-tokens 
  principal 
  {
    symbol: (string-ascii 10),
    decimals: uint,
    exchange-rate: uint, ;; rate to STX
    active: bool
  }
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

(define-read-only (get-contract-info)
  {
    fee-per-mb: (var-get fee-per-mb),
    fee-per-file: (var-get fee-per-file),
    penalty-rate: (var-get penalty-rate),
    grace-period: (var-get grace-period),
    paused: (var-get contract-paused),
    treasury: (var-get treasury-address)
  }
)

(define-read-only (get-subscription-plan (plan-id (string-ascii 20)))
  (map-get? subscription-plans plan-id)
)

(define-read-only (get-user-subscription (user principal))
  (map-get? user-subscriptions user)
)

(define-read-only (get-user-analytics (user principal))
  (map-get? user-analytics user)
)

(define-read-only (get-pricing-tier (tier-level uint))
  (map-get? pricing-tiers tier-level)
)

(define-read-only (calculate-tier-discount (storage-gb uint))
  (if (<= storage-gb u10) u0
    (if (<= storage-gb u100) u5
      (if (<= storage-gb u1000) u10
        (if (<= storage-gb u10000) u15
          u20))))
)

(define-read-only (get-discount-code (code (string-ascii 20)))
  (map-get? discount-codes code)
)

(define-read-only (calculate-subscription-discount (user principal) (amount uint))
  (match (map-get? user-subscriptions user)
    sub-info
    (if (is-eq (get status sub-info) "ACTIVE")
      (match (map-get? subscription-plans (get plan-id sub-info))
        plan-info
        (/ (* amount (get discount-rate plan-info)) u100)
        u0)
      u0)
    u0)
)

(define-read-only (estimate-total-cost (user principal) (file-size-mb uint) (priority-level uint))
  (let
    (
      (base-calc (calculate-total-fee file-size-mb))
      (priority-multiplier (if (is-eq priority-level u1) u100
                            (if (is-eq priority-level u2) u150 u200)))
      (base-total (/ (* (get total-fee base-calc) priority-multiplier) u100))
      (tier-discount (calculate-tier-discount (/ file-size-mb u1024)))
      (subscription-discount (calculate-subscription-discount user base-total))
      (total-discount (+ tier-discount subscription-discount))
      (discounted-amount (- base-total (/ (* base-total total-discount) u100)))
    )
    {
      base-fee: (get base-fee base-calc),
      size-fee: (get size-fee base-calc),
      priority-fee: (- base-total (get total-fee base-calc)),
      gross-total: base-total,
      total-discount: total-discount,
      final-amount: discounted-amount
    }
  )
)

(define-read-only (calculate-total-fee (file-size-mb uint))
  (let
    (
      (base-fee (var-get fee-per-file))
      (size-fee (* file-size-mb (var-get fee-per-mb)))
    )
    {
      base-fee: base-fee,
      size-fee: size-fee,
      total-fee: (+ base-fee size-fee)
    }
  )
)

;; ============================================================================
;; ADMIN FUNCTIONS
;; ============================================================================

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (create-subscription-plan 
  (plan-id (string-ascii 20))
  (name (string-ascii 50))
  (storage-limit-gb uint)
  (file-limit uint)
  (monthly-fee uint)
  (discount-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set subscription-plans plan-id {
      name: name,
      storage-limit-gb: storage-limit-gb,
      file-limit: file-limit,
      monthly-fee: monthly-fee,
      discount-rate: discount-rate,
      active: true
    })
    (ok true)
  )
)

(define-public (create-pricing-tier
  (tier-level uint)
  (min-storage-gb uint)
  (max-storage-gb uint)
  (discount-percentage uint)
  (tier-name (string-ascii 30)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set pricing-tiers tier-level {
      min-storage-gb: min-storage-gb,
      max-storage-gb: max-storage-gb,
      discount-percentage: discount-percentage,
      tier-name: tier-name
    })
    (ok true)
  )
)

(define-public (create-discount-code
  (code (string-ascii 20))
  (discount-percentage uint)
  (max-uses uint)
  (expiry-date uint)
  (min-purchase uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set discount-codes code {
      discount-percentage: discount-percentage,
      max-uses: max-uses,
      current-uses: u0,
      expiry-date: expiry-date,
      min-purchase: min-purchase,
      active: true,
      creator: tx-sender
    })
    (ok true)
  )
)

;; ============================================================================
;; SUBSCRIPTION FUNCTIONS
;; ============================================================================

(define-public (subscribe-to-plan (plan-id (string-ascii 20)))
  (let
    (
      (plan-info (unwrap! (map-get? subscription-plans plan-id) err-not-found))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (end-date (+ current-time u2592000)) ;; 30 days
    )
    (begin
      (asserts! (not (var-get contract-paused)) err-contract-paused)
      (asserts! (get active plan-info) err-invalid-tier)
      
      ;; Transfer subscription fee
      (try! (stx-transfer? (get monthly-fee plan-info) tx-sender (var-get treasury-address)))
      
      ;; Create or update subscription
      (map-set user-subscriptions tx-sender {
        plan-id: plan-id,
        start-date: current-time,
        end-date: end-date,
        auto-renew: true,
        storage-used-gb: u0,
        files-count: u0,
        status: "ACTIVE"
      })
      
      ;; Update analytics
      (map-set user-analytics tx-sender
        (merge (default-to {
          total-spent: u0,
          total-files: u0,
          total-storage-gb: u0,
          referral-earnings: u0,
          subscription-months: u0,
          last-payment: u0,
          payment-streak: u0,
          tier-level: u1
        } (map-get? user-analytics tx-sender))
        {
          total-spent: (+ (get monthly-fee plan-info) 
                         (get total-spent (default-to { total-spent: u0, total-files: u0, total-storage-gb: u0, referral-earnings: u0, subscription-months: u0, last-payment: u0, payment-streak: u0, tier-level: u1 } (map-get? user-analytics tx-sender)))),
          subscription-months: (+ u1 (get subscription-months (default-to { total-spent: u0, total-files: u0, total-storage-gb: u0, referral-earnings: u0, subscription-months: u0, last-payment: u0, payment-streak: u0, tier-level: u1 } (map-get? user-analytics tx-sender)))),
          last-payment: current-time
        })
      )
      
      (ok true)
    )
  )
)

;; ============================================================================
;; ENHANCED PAYMENT FUNCTIONS
;; ============================================================================

(define-public (create-storage-fee-advanced
  (user principal)
  (file-id (string-ascii 64))
  (file-size-mb uint)
  (priority-level uint))
  (let
    (
      (cost-estimate (estimate-total-cost user file-size-mb priority-level))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (due-date (+ current-time (var-get grace-period)))
      (tier-level (calculate-tier-discount (/ file-size-mb u1024)))
    )
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (asserts! (not (var-get contract-paused)) err-contract-paused)
      (asserts! (> file-size-mb u0) err-invalid-amount)
      (asserts! (<= priority-level u3) err-invalid-amount)
      
      (map-set storage-fees
        { user: user, file-id: file-id }
        {
          file-size-mb: file-size-mb,
          base-fee: (get base-fee cost-estimate),
          size-fee: (get size-fee cost-estimate),
          total-fee: (get gross-total cost-estimate),
          discounted-fee: (get final-amount cost-estimate),
          due-date: due-date,
          payment-status: "PENDING",
          penalty-amount: u0,
          created-at: current-time,
          tier-applied: tier-level,
          subscription-discount: (get total-discount cost-estimate),
          refund-eligible: true,
          priority-level: priority-level
        }
      )
      (ok (get final-amount cost-estimate))
    )
  )
)

(define-public (pay-with-discount-code
  (file-id (string-ascii 64))
  (discount-code (string-ascii 20)))
  (let
    (
      (user tx-sender)
      (fee-info (unwrap! (map-get? storage-fees { user: user, file-id: file-id }) err-not-found))
      (code-info (unwrap! (map-get? discount-codes discount-code) err-not-found))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (base-amount (get discounted-fee fee-info))
    )
    (begin
      (asserts! (not (var-get contract-paused)) err-contract-paused)
      (asserts! (is-eq (get payment-status fee-info) "PENDING") err-already-paid)
      (asserts! (get active code-info) err-discount-expired)
      (asserts! (< current-time (get expiry-date code-info)) err-discount-expired)
      (asserts! (< (get current-uses code-info) (get max-uses code-info)) err-discount-expired)
      (asserts! (>= base-amount (get min-purchase code-info)) err-insufficient-payment)
      
      (let
        (
          (additional-discount (/ (* base-amount (get discount-percentage code-info)) u100))
          (final-amount (- base-amount additional-discount))
          (payment-id (+ (var-get payment-counter) u1))
        )
        
        ;; Transfer payment
        (try! (stx-transfer? final-amount user (var-get treasury-address)))
        
        ;; Update discount code usage
        (map-set discount-codes discount-code
          (merge code-info { current-uses: (+ (get current-uses code-info) u1) }))
        
        ;; Update storage fee
        (map-set storage-fees
          { user: user, file-id: file-id }
          (merge fee-info { payment-status: "PAID" }))
        
        ;; Record payment
        (map-set user-payments
          { user: user, payment-id: payment-id }
          {
            file-id: file-id,
            amount-paid: final-amount,
            payment-method: "STX",
            payment-date: current-time,
            transaction-id: (keccak256 (concat (unwrap-panic (to-consensus-buff? user)) 
                                             (unwrap-panic (to-consensus-buff? payment-id)))),
            refunded: false,
            refund-amount: u0,
            referral-code: none,
            gas-fee: u0
          }
        )
        
        (var-set payment-counter payment-id)
        (ok final-amount)
      )
    )
  )
)

;; ============================================================================
;; REFERRAL SYSTEM
;; ============================================================================

(define-public (create-referral-code (referral-code (string-ascii 20)))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (begin
      (asserts! (is-none (map-get? referral-codes referral-code)) err-already-paid)
      (map-set referral-codes referral-code {
        owner: tx-sender,
        total-referrals: u0,
        total-earnings: u0,
        active: true,
        created-at: current-time
      })
      (ok true)
    )
  )
)

(define-public (pay-with-referral
  (file-id (string-ascii 64))
  (referral-code (string-ascii 20)))
  (let
    (
      (user tx-sender)
      (fee-info (unwrap! (map-get? storage-fees { user: user, file-id: file-id }) err-not-found))
      (referral-info (unwrap! (map-get? referral-codes referral-code) err-not-found))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (amount (get discounted-fee fee-info))
      (referral-bonus (/ (* amount (var-get referral-bonus-rate)) u100))
      (payment-id (+ (var-get payment-counter) u1))
    )
    (begin
      (asserts! (not (var-get contract-paused)) err-contract-paused)
      (asserts! (is-eq (get payment-status fee-info) "PENDING") err-already-paid)
      (asserts! (get active referral-info) err-not-found)
      
      ;; Transfer payment
      (try! (stx-transfer? amount user (var-get treasury-address)))
      
      ;; Pay referral bonus
      (try! (stx-transfer? referral-bonus (var-get treasury-address) (get owner referral-info)))
      
      ;; Update referral stats
      (map-set referral-codes referral-code
        (merge referral-info {
          total-referrals: (+ (get total-referrals referral-info) u1),
          total-earnings: (+ (get total-earnings referral-info) referral-bonus)
        }))
      
      ;; Update payment record
      (map-set user-payments
        { user: user, payment-id: payment-id }
        {
          file-id: file-id,
          amount-paid: amount,
          payment-method: "STX",
          payment-date: current-time,
          transaction-id: (keccak256 (concat (unwrap-panic (to-consensus-buff? user)) 
                                           (unwrap-panic (to-consensus-buff? payment-id)))),
          refunded: false,
          refund-amount: u0,
          referral-code: (some referral-code),
          gas-fee: u0
        }
      )
      
      (var-set payment-counter payment-id)
      (ok amount)
    )
  )
)

;; ============================================================================
;; REFUND & DISPUTE SYSTEM
;; ============================================================================

(define-public (request-refund (file-id (string-ascii 64)) (reason (string-ascii 100)))
  (let
    (
      (user tx-sender)
      (fee-info (unwrap! (map-get? storage-fees { user: user, file-id: file-id }) err-not-found))
      (dispute-id (+ (var-get dispute-counter) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (begin
      (asserts! (is-eq (get payment-status fee-info) "PAID") err-not-found)
      (asserts! (get refund-eligible fee-info) err-refund-not-allowed)
      
      (map-set payment-disputes dispute-id {
        user: user,
        file-id: file-id,
        amount: (get discounted-fee fee-info),
        reason: reason,
        status: "PENDING",
        created-at: current-time,
        resolver: none
      })
      
      (var-set dispute-counter dispute-id)
      (ok dispute-id)
    )
  )
)

(define-public (resolve-dispute (dispute-id uint) (approved bool))
  (let
    (
      (dispute-info (unwrap! (map-get? payment-disputes dispute-id) err-not-found))
    )
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (asserts! (is-eq (get status dispute-info) "PENDING") err-not-found)
      
      (if approved
        (begin
          ;; Process refund
          (try! (stx-transfer? (get amount dispute-info) (var-get treasury-address) (get user dispute-info)))
          (map-set payment-disputes dispute-id
            (merge dispute-info { 
              status: "RESOLVED",
              resolver: (some tx-sender)
            }))
        )
        (map-set payment-disputes dispute-id
          (merge dispute-info { 
            status: "REJECTED",
            resolver: (some tx-sender)
          }))
      )
      (ok approved)
    )
  )
)

;; ============================================================================
;; AUTO-PAYMENT SYSTEM
;; ============================================================================

(define-public (setup-auto-payment (max-amount uint))
  (begin
    (map-set auto-payment-settings tx-sender {
      enabled: true,
      payment-method: "STX",
      max-amount: max-amount,
      last-auto-payment: u0,
      failed-attempts: u0
    })
    (ok true)
  )
)

(define-public (execute-auto-payment (user principal) (file-id (string-ascii 64)))
  (let
    (
      (auto-settings (unwrap! (map-get? auto-payment-settings user) err-not-found))
      (fee-info (unwrap! (map-get? storage-fees { user: user, file-id: file-id }) err-not-found))
      (amount (get discounted-fee fee-info))
    )
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (asserts! (get enabled auto-settings) err-unauthorized)
      (asserts! (<= amount (get max-amount auto-settings)) err-insufficient-payment)
      (asserts! (is-eq (get payment-status fee-info) "PENDING") err-already-paid)
      
      ;; Execute payment (simplified - would need more robust implementation)
      (try! (stx-transfer? amount user (var-get treasury-address)))
      
      ;; Update auto-payment settings
      (map-set auto-payment-settings user
        (merge auto-settings {
          last-auto-payment: (unwrap-panic (get-block-info? time (- block-height u1))),
          failed-attempts: u0
        }))
      
      (ok amount)
    )
  )
)

;; ============================================================================
;; ANALYTICS & REPORTING
;; ============================================================================

(define-read-only (get-user-payment-history (user principal) (limit uint))
  ;; This would return payment history - simplified implementation
  (ok "Payment history retrieved")
)

(define-read-only (get-revenue-analytics (start-date uint) (end-date uint))
  ;; This would return revenue analytics - simplified implementation
  (if (is-eq tx-sender contract-owner)
    (ok "Revenue analytics retrieved")
    err-owner-only)
)

;; ============================================================================
;; EMERGENCY FUNCTIONS
;; ============================================================================

(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (stx-transfer? amount (as-contract tx-sender) contract-owner))
    (ok true)
  )
)

(define-public (migrate-user-data (old-user principal) (new-user principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; Migration logic would go here
    (ok true)
  )
)