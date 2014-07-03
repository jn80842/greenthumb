#lang racket

(require 
 ;; ISA independent
 "ast.rkt" "controller.rkt" "stat.rkt"
 ;; ISA dependent
 "vpe/state.rkt" "vpe/print.rkt"
 "vpe/interpret-racket.rkt" "vpe/stochastic-support.rkt"
 )

(provide stochastic-optimize)

;;;;;;;;;;;;;;;;;;;;; Parameters ;;;;;;;;;;;;;;;;;;;
(define w-error 9999)
(define beta 1)
(define opcode-mass 0.35)
(define operand-mass 0.35)
(define swap-mass 0.15)
(define inst-mass 0.15)
(define nop-mass 0.8)
(define ntests 8)
  
  
;;;;;;;;;;;;;;;;;;;;; Functions ;;;;;;;;;;;;;;;;;;
(define (stochastic-optimize spec info constraint 
                             #:assume [assumption (no-assumption)]
                             #:synthesize [syn-mode #f]
                             #:name [name "temp"])
  (init-stochastic)
  ;; Generate testcases
  (when debug 
        (pretty-display ">>> Phase 1: genenrate input states"))
  (define inputs (generate-input-states ntests spec info assumption #:bit 32))

  (when debug
        (for ([i inputs])
             (display-state i))
        (pretty-display ">>> Phase 2: genenrate output states"))
  (define outputs (map (lambda (x) (interpret spec x)) inputs))
  (when debug
        (for ([i outputs])
             (display-state i)))

  ;; MCMC sampling
  (define sketch (random-insts (vector-length spec)))
  (when debug
        (pretty-display ">>> Phase 3: stochastic search")
        (pretty-display "sketch:")
        (print-struct sketch))
  (define stat (new stat% 
                    [best-correct-program spec] 
                    [best-correct-cost (performance-cost spec)]
                    [name name]))
  (mcmc-main spec (if syn-mode sketch spec) 
             inputs outputs constraint info assumption stat)
  )

(define (random-insts n)
  (for/vector ([i n])
       (define opcode-id (random (vector-length inst-id)))
       (define opcode-name (vector-ref inst-id opcode-id))
       (define args (random-args-from-op opcode-name))
       (inst opcode-id args)))

(define (random-from-list-ex lst ex)
  (let ([new-lst (remove ex lst)])
    (list-ref new-lst (random (length new-lst)))))

(define (random-from-vec-ex vec ex)
  (define len (vector-length vec))
  (define (inner)
    (define sample (vector-ref vec (random len)))
    (if (eq? sample ex)
        (inner)
        sample))
  (if (= len 1)
      (vector-ref vec 0)
      (inner)))

(define (random-from-vec vec)
  (vector-ref vec (random (vector-length vec))))

(define (mutate p stat)
  (define type (random))
  (define new-p (vector-copy p))
  (define vec-len (vector-length new-p))
  (define index (random vec-len))
  (define entry (vector-ref new-p index))
  (define opcode-id (inst-op entry))
  (define opcode-name (vector-ref inst-id opcode-id))
  (define nop (get-nop-opcode))
  (define new #f)
  (when debug (pretty-display (format " >> mutate prop = ~a, index = ~a" type index)))
  (cond
   ;; opcode
   [(and (not (equal? opcode-name nop)) (< type opcode-mass))
    (define class (get-class opcode-name))
    (when debug
          (pretty-display (format " >> mutate opcode"))
          (pretty-display (format " --> org = ~a ~a" opcode-name opcode-id))
          (pretty-display (format " --> class = ~a" class)))
    (when class
      (define new-opcode-name (random-from-list-ex class opcode-name))
      (define new-opcode-id (vector-member new-opcode-name inst-id))
      (when debug
            (pretty-display (format " --> new = ~a ~a" new-opcode-name new-opcode-id)))
      (vector-set! new-p index (inst new-opcode-id (inst-args entry)))
      (send stat inc-propose 0)
      (set! new #t)
      )
    ]

   ;; operand
   [(and (not (equal? opcode-name nop)) (< type (+ opcode-mass operand-mass)))
    (when debug (pretty-display " >> mutate operand"))
    (define ranges (get-arg-ranges opcode-name))
    (when (> (vector-length ranges) 0)
          (define args (vector-copy (inst-args entry)))
          (define change (random (vector-length ranges)))
          (define valid-vals (vector-ref ranges change))
          (define new-val (random-from-vec-ex valid-vals (vector-ref args change)))
          (when debug
                (pretty-display (format " --> org = ~a ~a" opcode-name args))
                (pretty-display (format " --> new = [~a]->~a)" change new-val)))
          (vector-set! args change new-val)
          (vector-set! new-p index (inst opcode-id args))
          (send stat inc-propose 1)
          (set! new #t)
          )
    ]
   
   ;; swap
   [(if (not (equal? opcode-name nop))
        (< type (+ opcode-mass operand-mass swap-mass))
        (< type (/ swap-mass (+ swap-mass inst-mass))))
    (define index2 (random-from-list-ex (range vec-len) index))
    (when debug
          (pretty-display " >> mutate swap")
          (pretty-display (format " --> swap = ~a" index2)))
    (vector-set! new-p index (vector-ref new-p index2))
    (vector-set! new-p index2 entry)
    (send stat inc-propose 2)
    (set! new #t)
    ]
   
   ;; brand new instruction
   [else
    (define new-opcode-name
      (if (and (not (equal? opcode-name nop)) (< (random) nop-mass))
          (begin (send stat inc-propose 4) nop)
          (begin (send stat inc-propose 3) (random-from-vec-ex inst-id opcode-name))))
    (define new-opcode-id (vector-member new-opcode-name inst-id))
    (when debug
          (pretty-display (format " >> mutate instruction ~a" new-opcode-name)))
    (define new-args (random-args-from-op new-opcode-name))
    (vector-set! new-p index (inst new-opcode-id new-args))
    (set! new #t)
    ])

  (if new
      new-p
      (mutate p stat))
      )

(define (random-args-from-op opcode-name)
  (define ranges (get-arg-ranges opcode-name))
  (when debug (pretty-display (format " --> ranges ~a" ranges)))
  (for/vector ([i (vector-length ranges)])
              (random-from-vec (vector-ref ranges i))))
  

(define (mcmc-main target init inputs outputs constraint info assumption stat)
  (pretty-display ">>> start MCMC sampling")
  (define syn-mode #t)

  (define (cost-one-input program input output)
    (with-handlers* ([exn:break? (lambda (e) (raise e))]
                     [exn? (lambda (e) 
                             (when debug (pretty-display "Error!"))
                             w-error)])
      (let ([program-out (interpret program input)])
        (correctness-cost output program-out constraint stat)
        )))

  (define (cost-all-inputs program okay-cost)
    (define correct 0)
    (define change-mode #f)
    (for ([input inputs]
          [output outputs])
         (when correct
               (set! correct (+ correct (cost-one-input program input output)))
               (when (> correct okay-cost)
                     (set! correct #f))))

    (when (equal? correct 0)
          (send stat inc-correct)
          (if (program-eq? target program info constraint #:bit 32 #:assume assumption)
              (begin
                (when syn-mode (set! change-mode #t) (set! syn-mode #f))
                ;(send stat inc-correct)
                )
              (set! correct 1)))

    (and correct
         (let ([total-cost 
                (if syn-mode correct (+ (performance-cost program) correct))])
           (when (< total-cost (get-field best-cost stat))
                 (send stat update-best program total-cost)
                 )
           (when (and (= correct 0) (< total-cost (get-field best-correct-cost stat)))
                 (send stat update-best-correct program total-cost)
                 )
           (and (or (<= total-cost okay-cost) change-mode) total-cost)))
    )

  (define (accept-cost current-cost)
    (- current-cost (/ (log (random)) beta)))

  ;; Main loop
  (define (iter current current-cost)
    (send stat inc-iter)
    (define proposal (mutate current stat))
    (when debug
          (pretty-display (format "================ Current (syn=~a) =================" syn-mode))
          (print-struct current)
          (define cost (cost-all-inputs current (arithmetic-shift 1 32)))
          (pretty-display (format "actual cost: ~a" cost))
          (pretty-display (format "================ Propose (syn=~a) =================" syn-mode))
          (print-struct proposal)
          )
    (define okay-cost (accept-cost current-cost))
    (define proposal-cost (cost-all-inputs proposal okay-cost))
    (when debug
          (pretty-display (format "current cost: ~a" current-cost))
          (pretty-display (format "okay cost: ~a" okay-cost))
          (pretty-display (format "proposal cost: ~a" proposal-cost)))

    (if proposal-cost
        (begin
          (when debug
                (pretty-display "================ ACCEPT! =================")
                (print-struct proposal))
          (send stat inc-accept)
          (when (> proposal-cost current-cost) 
                (send stat inc-accept-higher))
          (iter proposal proposal-cost))
        (iter current current-cost)))

  (with-handlers ([exn:break? (lambda (e) 
                                (send stat print-stat-to-file)
                                )])
    (timeout 1000 
             (iter init (cost-all-inputs init (arithmetic-shift 1 32)))
             ))
  )