;; Innovation Development Contract
;; Advances adaptive technology solutions

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_PROJECT_NOT_FOUND (err u501))
(define-constant ERR_INSUFFICIENT_FUNDING (err u502))
(define-constant ERR_INVALID_STATUS (err u503))

;; Project status
(define-constant STATUS_PROPOSED u0)
(define-constant STATUS_FUNDED u1)
(define-constant STATUS_IN_DEVELOPMENT u2)
(define-constant STATUS_TESTING u3)
(define-constant STATUS_COMPLETED u4)
(define-constant STATUS_DEPLOYED u5)

;; Innovation projects
(define-map innovation-projects
  { project-id: uint }
  {
    proposer: principal,
    title: (string-ascii 200),
    description: (string-ascii 1000),
    target-disability: (string-ascii 100),
    innovation-type: (string-ascii 100),
    funding-required: uint,
    funding-received: uint,
    status: uint,
    created-at: uint,
    milestones-completed: uint,
    total-milestones: uint,
    impact-score: uint
  }
)

(define-data-var project-counter uint u0)

;; Project funding
(define-map project-funding
  { project-id: uint, funder: principal }
  { amount: uint, funded-at: uint }
)

;; Innovation fund
(define-data-var innovation-fund uint u0)

;; Research categories
(define-map research-categories
  { category: (string-ascii 100) }
  {
    priority-level: uint,
    funding-allocated: uint,
    active-projects: uint
  }
)

;; Initialize research categories
(map-set research-categories
  { category: "mobility-assistance" }
  { priority-level: u5, funding-allocated: u0, active-projects: u0 })

(map-set research-categories
  { category: "communication-aids" }
  { priority-level: u5, funding-allocated: u0, active-projects: u0 })

(map-set research-categories
  { category: "sensory-enhancement" }
  { priority-level: u4, funding-allocated: u0, active-projects: u0 })

;; Propose innovation project
(define-public (propose-project
  (title (string-ascii 200))
  (description (string-ascii 1000))
  (target-disability (string-ascii 100))
  (innovation-type (string-ascii 100))
  (funding-required uint)
  (total-milestones uint))
  (let
    ((new-id (+ (var-get project-counter) u1)))
    (map-set innovation-projects
      { project-id: new-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        target-disability: target-disability,
        innovation-type: innovation-type,
        funding-required: funding-required,
        funding-received: u0,
        status: STATUS_PROPOSED,
        created-at: block-height,
        milestones-completed: u0,
        total-milestones: total-milestones,
        impact-score: u0
      }
    )
    (var-set project-counter new-id)
    (ok new-id)
  )
)

;; Fund project
(define-public (fund-project (project-id uint) (amount uint))
  (let
    ((project (unwrap! (map-get? innovation-projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND)))
    ;; In a real implementation, handle STX transfers
    (map-set project-funding
      { project-id: project-id, funder: tx-sender }
      { amount: amount, funded-at: block-height }
    )
    (map-set innovation-projects
      { project-id: project-id }
      (merge project {
        funding-received: (+ (get funding-received project) amount),
        status: (if (>= (+ (get funding-received project) amount) (get funding-required project))
                   STATUS_FUNDED
                   (get status project))
      })
    )
    (ok true)
  )
)

;; Update project milestone
(define-public (update-milestone (project-id uint))
  (let
    ((project (unwrap! (map-get? innovation-projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get proposer project)) ERR_UNAUTHORIZED)
    (let
      ((new-milestones (+ (get milestones-completed project) u1)))
      (map-set innovation-projects
        { project-id: project-id }
        (merge project {
          milestones-completed: new-milestones,
          status: (if (is-eq new-milestones (get total-milestones project))
                     STATUS_COMPLETED
                     STATUS_IN_DEVELOPMENT)
        })
      )
      (ok new-milestones)
    )
  )
)

;; Update project status
(define-public (update-project-status (project-id uint) (new-status uint))
  (let
    ((project (unwrap! (map-get? innovation-projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get proposer project)) ERR_UNAUTHORIZED)
    (asserts! (<= new-status STATUS_DEPLOYED) ERR_INVALID_STATUS)
    (map-set innovation-projects
      { project-id: project-id }
      (merge project { status: new-status })
    )
    (ok true)
  )
)

;; Rate project impact
(define-public (rate-project-impact (project-id uint) (impact-score uint))
  (let
    ((project (unwrap! (map-get? innovation-projects { project-id: project-id }) ERR_PROJECT_NOT_FOUND)))
    ;; In production, add proper authorization for rating
    (asserts! (<= impact-score u100) ERR_INVALID_STATUS)
    (map-set innovation-projects
      { project-id: project-id }
      (merge project { impact-score: impact-score })
    )
    (ok true)
  )
)

;; Get project details
(define-read-only (get-project (project-id uint))
  (map-get? innovation-projects { project-id: project-id })
)

;; Get project funding
(define-read-only (get-project-funding (project-id uint) (funder principal))
  (map-get? project-funding { project-id: project-id, funder: funder })
)

;; Get research category
(define-read-only (get-research-category (category (string-ascii 100)))
  (map-get? research-categories { category: category })
)

;; Get project count
(define-read-only (get-project-count)
  (var-get project-counter)
)

;; Calculate project progress
(define-read-only (get-project-progress (project-id uint))
  (match (map-get? innovation-projects { project-id: project-id })
    project (if (> (get total-milestones project) u0)
              (/ (* (get milestones-completed project) u100) (get total-milestones project))
              u0)
    u0
  )
)
