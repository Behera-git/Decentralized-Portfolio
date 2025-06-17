;; Map to store user portfolio summaries
(define-map user-portfolios
  {user: principal}  ;; key
  {summary: (string-ascii 200)}) ;; value

(define-constant err-empty-summary (err u100))

;; Public function to set/update portfolio summary
(define-public (set-portfolio (summary (string-ascii 200)))
  (begin
    (asserts! (> (len summary) u0) err-empty-summary)
    (map-set user-portfolios {user: tx-sender} {summary: summary})
    (ok true)))

;; Read-only function to get user's portfolio
(define-read-only (get-my-portfolio)
  (let ((entry (map-get? user-portfolios {user: tx-sender})))
    (ok (match entry
         val (some {summary: (get summary val)})
         none))))
