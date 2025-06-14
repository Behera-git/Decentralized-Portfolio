;; Decentralized Portfolio Contract
;; Showcase skills and projects on the blockchain with immutable verification

;; Define portfolio entry structure
(define-map portfolio-entries 
  {entry-id: uint} 
  {
    owner: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    entry-type: (string-ascii 20), ;; "skill" or "project"
    category: (string-ascii 50),
    skills-used: (string-ascii 200),
    project-url: (optional (string-ascii 200)),
    verification-status: (string-ascii 20), ;; "pending", "verified", "rejected"
    created-at: uint,
    updated-at: uint
  })

;; Track entry counter and user portfolios
(define-data-var entry-counter uint u0)
(define-map user-portfolios principal (list 30 uint))

;; Portfolio profile information
(define-map user-profiles 
  principal 
  {
    name: (string-ascii 100),
    bio: (string-ascii 300),
    contact-info: (string-ascii 200),
    profile-created-at: uint,
    total-entries: uint,
    verified-entries: uint
  })

;; Endorsement system for skills and projects
(define-map endorsements 
  {entry-id: uint, endorser: principal}
  {
    endorsed-at: uint,
    endorsement-note: (string-ascii 200)
  })

(define-map entry-endorsement-count uint uint)

;; Constants for error handling
(define-constant err-invalid-entry-id (err u400))
(define-constant err-entry-not-found (err u401))
(define-constant err-unauthorized (err u402))
(define-constant err-invalid-input (err u403))
(define-constant err-already-endorsed (err u404))
(define-constant err-self-endorsement (err u405))
(define-constant err-invalid-entry-type (err u406))

;; Function 1: Create Portfolio Entry
;; Allows users to add skills or projects to their decentralized portfolio
(define-public (create-portfolio-entry 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (entry-type (string-ascii 20))
  (category (string-ascii 50))
  (skills-used (string-ascii 200))
  (project-url (optional (string-ascii 200))))
  (let (
    (new-entry-id (+ (var-get entry-counter) u1))
    (current-block-height block-height)
  )
  (begin
    ;; Validate inputs
    (asserts! (> (len title) u0) err-invalid-input)
    (asserts! (> (len description) u0) err-invalid-input)
    (asserts! (or (is-eq entry-type "skill") (is-eq entry-type "project")) err-invalid-entry-type)
    (asserts! (> (len category) u0) err-invalid-input)
    
    ;; Create the portfolio entry
    (map-set portfolio-entries 
      {entry-id: new-entry-id}
      {
        owner: tx-sender,
        title: title,
        description: description,
        entry-type: entry-type,
        category: category,
        skills-used: skills-used,
        project-url: project-url,
        verification-status: "pending",
        created-at: current-block-height,
        updated-at: current-block-height
      })
    
    ;; Initialize endorsement counter
    (map-set entry-endorsement-count new-entry-id u0)
    
    ;; Update user's portfolio list
    (let ((current-entries (default-to (list) (map-get? user-portfolios tx-sender))))
      (map-set user-portfolios tx-sender (unwrap! (as-max-len? (append current-entries new-entry-id) u30) err-invalid-input)))
    
    ;; Update user profile entry count
    (let ((current-profile (map-get? user-profiles tx-sender)))
      (match current-profile
        profile-data 
          (map-set user-profiles tx-sender 
            (merge profile-data {
              total-entries: (+ (get total-entries profile-data) u1)
            }))
        ;; Create basic profile if doesn't exist
        (map-set user-profiles tx-sender {
          name: "",
          bio: "",
          contact-info: "",
          profile-created-at: current-block-height,
          total-entries: u1,
          verified-entries: u0
        })))
    
    ;; Increment counter
    (var-set entry-counter new-entry-id)
    
    ;; Print entry creation notification
    (print {
      action: "portfolio-entry-created",
      entry-id: new-entry-id,
      owner: tx-sender,
      title: title,
      entry-type: entry-type,
      category: category
    })
    
    (ok new-entry-id))))

;; Function 2: Endorse Portfolio Entry
;; Allows users to endorse others' skills and projects for credibility
(define-public (endorse-entry 
  (entry-id uint)
  (endorsement-note (string-ascii 200)))
  (let (
    (entry-data (unwrap! (map-get? portfolio-entries {entry-id: entry-id}) err-entry-not-found))
    (current-endorsements (default-to u0 (map-get? entry-endorsement-count entry-id)))
    (endorsement-key {entry-id: entry-id, endorser: tx-sender})
  )
  (begin
    ;; Validate endorsement
    (asserts! (not (is-eq tx-sender (get owner entry-data))) err-self-endorsement)
    (asserts! (is-none (map-get? endorsements endorsement-key)) err-already-endorsed)
    (asserts! (> (len endorsement-note) u0) err-invalid-input)
    
    ;; Create the endorsement
    (map-set endorsements 
      endorsement-key
      {
        endorsed-at: block-height,
        endorsement-note: endorsement-note
      })
    
    ;; Update endorsement count
    (map-set entry-endorsement-count entry-id (+ current-endorsements u1))
    
    ;; Update verification status based on endorsement threshold
    (let ((new-endorsement-count (+ current-endorsements u1)))
      (if (>= new-endorsement-count u3) ;; 3 endorsements = verified
        (begin
          (map-set portfolio-entries 
            {entry-id: entry-id}
            (merge entry-data {
              verification-status: "verified",
              updated-at: block-height
            }))
          ;; Update user's verified entries count
          (let ((owner-profile (unwrap! (map-get? user-profiles (get owner entry-data)) err-entry-not-found)))
            (map-set user-profiles (get owner entry-data)
              (merge owner-profile {
                verified-entries: (+ (get verified-entries owner-profile) u1)
              }))))
        true))
    
    ;; Print endorsement notification
    (print {
      action: "entry-endorsed",
      entry-id: entry-id,
      endorser: tx-sender,
      owner: (get owner entry-data),
      total-endorsements: (+ current-endorsements u1),
      verification-status: (if (>= (+ current-endorsements u1) u3) "verified" "pending")
    })
    
    (ok {
      entry-id: entry-id,
      total-endorsements: (+ current-endorsements u1),
      verification-achieved: (>= (+ current-endorsements u1) u3)
    }))))

;; Helper function: Get portfolio entry details
(define-read-only (get-portfolio-entry (entry-id uint))
  (let ((entry-data (map-get? portfolio-entries {entry-id: entry-id})))
    (match entry-data
      entry-info 
        (ok (some {
          entry: entry-info,
          endorsement-count: (default-to u0 (map-get? entry-endorsement-count entry-id))
        }))
      (ok none))))

;; Helper function: Get user's portfolio
(define-read-only (get-user-portfolio (user principal))
  (let ((user-entries (default-to (list) (map-get? user-portfolios user)))
        (user-profile (map-get? user-profiles user)))
    (ok {
      profile: user-profile,
      entries: user-entries,
      total-entries: (len user-entries)
    })))

;; Helper function: Get user profile
(define-read-only (get-user-profile (user principal))
  (ok (map-get? user-profiles user)))

;; Helper function: Get endorsement details
(define-read-only (get-endorsement (entry-id uint) (endorser principal))
  (ok (map-get? endorsements {entry-id: entry-id, endorser: endorser})))

;; Helper function: Get endorsement count for entry
(define-read-only (get-endorsement-count (entry-id uint))
  (ok (default-to u0 (map-get? entry-endorsement-count entry-id))))

;; Helper function: Get total portfolio entries
(define-read-only (get-total-entries)
  (ok (var-get entry-counter)))

;; Helper function: Check if entry exists
(define-read-only (entry-exists (entry-id uint))
  (ok (is-some (map-get? portfolio-entries {entry-id: entry-id}))))