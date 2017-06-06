#lang racket

(provide get-weighted-random-opcode)

(define opcode-distros
  (hash
   (vector 'mul '|| '||) 935
   (vector 'add '|| '||) 5439
   (vector 'add '|| 'lsl) 18
   (vector 'add '|| 'asr#) 203
   (vector 'add '|| 'lsl#) 2153
   (vector 'add '|| 'lsr#) 556
   (vector 'add '|| 'ror#) 62
   (vector 'add 'eq '||) 11
   (vector 'add 'ne '||) 41
   (vector 'add 'lt '||) 28
   (vector 'and '|| '||) 1433
   (vector 'and '|| 'lsl) 14
   (vector 'and '|| 'lsl#) 126
   (vector 'and '|| 'lsr#) 268
   (vector 'and 'ne '||) 11
   (vector 'orr '|| '||) 1195
   (vector 'orr '|| 'lsl) 103
   (vector 'orr '|| 'lsr) 26
   (vector 'orr '|| 'lsl#) 688
   (vector 'orr '|| 'lsr#) 434
   (vector 'orr '|| 'ror#) 24
   (vector 'eor '|| 'lsl#) 328
   (vector 'eor '|| 'lsr#) 520
   (vector 'eor '|| 'ror#) 12
   (vector 'eor '|| '||) 1622
   (vector 'eor 'ne '||) 25
   (vector 'asr '|| '||) 67
   (vector 'lsl '|| '||) 332
   (vector 'lsr '|| '||) 116
   (vector 'ror '|| '||) 3
   (vector 'uxtah '|| '||) 39
   (vector 'sub '|| '||) 1989
   (vector 'sub '|| 'lsl) 11
   (vector 'sub '|| 'asr#) 37
   (vector 'sub '|| 'lsl#) 76
   (vector 'sub '|| 'lsr#) 12
   (vector 'sub 'hi '||) 11
   (vector 'sub 'cc '||) 14
   (vector 'sub 'cs '||) 20
   (vector 'sub 'ge '||) 20
   (vector 'bic '|| 'lsl) 13
   (vector 'bic '|| 'asr#) 24
   (vector 'bic '|| '||) 103
   (vector 'add# '|| '||) 13963
   (vector 'add# 'eq '||) 149
   (vector 'add# 'ne '||) 213
   (vector 'add# 'ls '||) 156
   (vector 'add# 'hi '||) 26
   (vector 'add# 'cs '||) 34
   (vector 'add# 'lt '||) 79
   (vector 'add# 'ge '||) 90
   (vector 'sub# '|| '||) 4657
   (vector 'sub# 'ne '||) 67
   (vector 'sub# 'hi '||) 11
   (vector 'sub# 'ge '||) 13
   (vector 'rsb# '|| '||) 661
   (vector 'rsb# 'ne '||) 67
   (vector 'rsb# 'lt '||) 94
   (vector 'and# '|| '||) 1489
   (vector 'and# 'eq '||) 87
   (vector 'and# 'ne '||) 100
   (vector 'and# 'hi '||) 29
   (vector 'and# 'ge '||) 12
   (vector 'orr# '|| '||) 389
   (vector 'orr# 'eq '||) 84
   (vector 'orr# 'ne '||) 65
   (vector 'orr# 'ls '||) 11
   (vector 'orr# 'lt '||) 11
   (vector 'eor# '|| '||) 362
   (vector 'bic# '|| '||) 190
   (vector 'asr# '|| '||) 777
   (vector 'asr# 'lt '||) 11
   (vector 'lsl# '|| '||) 2472
   (vector 'lsl# 'ls '||) 135
   (vector 'lsl# 'cc '||) 131
   (vector 'lsl# 'lt '||) 11
   (vector 'lsr# '|| '||) 1432
   (vector 'lsr# 'eq '||) 37
   (vector 'ror# '|| '||) 21
   (vector 'mov '|| '||) 29236
   (vector 'mov 'eq '||) 426
   (vector 'mov 'ne '||) 624
   (vector 'mov 'ls '||) 79
   (vector 'mov 'hi '||) 50
   (vector 'mov 'cc '||) 113
   (vector 'mov 'cs '||) 131
   (vector 'mov 'lt '||) 275
   (vector 'mov 'ge '||) 224
   (vector 'mvn '|| '||) 308
   (vector 'mvn 'eq '||) 40
   (vector 'mvn 'ne '||) 27
   (vector 'mvn '|| 'lsl#) 44
   (vector 'mvn '|| 'lsr#) 47
   (vector 'rev '|| '||) 49
   (vector 'rev16 '|| '||) 8
   (vector 'uxth '|| '||) 856
   (vector 'uxth 'eq '||) 12
   (vector 'uxtb '|| '||) 494
   (vector 'uxtb 'ge '||) 35
   (vector 'clz '|| '||) 68
   (vector 'mov# '|| '||) 14406
   (vector 'mov# 'eq '||) 836
   (vector 'mov# 'ne '||) 766
   (vector 'mov# 'ls '||) 120
   (vector 'mov# 'hi '||) 84
   (vector 'mov# 'cc '||) 236
   (vector 'mov# 'cs '||) 210
   (vector 'mov# 'lt '||) 371
   (vector 'mov# 'ge '||) 338
   (vector 'mvn# '|| '||) 1149
   (vector 'mvn# 'eq '||) 40
   (vector 'mvn# 'ne '||) 43
   (vector 'mvn# 'hi '||) 12
   (vector 'movw# '|| '||) 14424
   (vector 'movw# 'eq '||) 121
   (vector 'movw# 'ne '||) 137
   (vector 'movw# 'ge '||) 73
   (vector 'movt# '|| '||) 13133
   (vector 'movt# 'eq '||) 97
   (vector 'movt# 'ne '||) 152
   (vector 'mla '|| '||) 650
   (vector 'mls '|| '||) 77
   (vector 'smull '|| '||) 151
   (vector 'umull '|| '||) 124
   (vector 'bfi '|| '||) 316
   (vector 'sbfx '|| '||) 94
   (vector 'ubfx '|| '||) 1104
   (vector 'ldr# '|| '||) 37626
   (vector 'str# '|| '||) 21400
   (vector 'tst '|| '||) 128
   (vector 'cmp '|| '||) 7228
   ))

(define default-weight (λ () 10))

(define cached-distribution-tables '())

(define (weighted-random-inst inst-list)
  (map (λ (inst) (hash-ref opcode-distros inst default-weight)) inst-list))

(define (get-weighted-random-opcode inst-list)
  (define sum 0)
  (define prop '())
  (define cached-prop (findf (λ (cache) (equal? (car cache) inst-list)) cached-distribution-tables))
  (pretty-display "looking for cached distro list")
  (pretty-display cached-prop)
  (if (list? cached-prop)
      (pretty-display (length cached-prop))
      (pretty-display "cached-prop is not a list"))
  (if cached-prop
      (set! prop (cadr cached-prop))
      (begin
        (pretty-display "didn't find it, let's make one")
        (set! prop (map (λ(x)
                            (let ([v (hash-ref opcode-distros x default-weight)])
                              (set! sum (+ sum v))
                              sum)) inst-list))
        (set! prop (map (λ (x) (exact->inexact (/ x sum))) prop))
        (if (empty? cached-distribution-tables)
            (set! cached-distribution-tables (list (list inst-list prop)))
            (set! cached-distribution-tables (cons (list inst-list prop) cached-distribution-tables)))))
  (pretty-display "done! we have a prop list")
  (pretty-display prop)
  (define rand (random))
  (define (loop name-list prop-list)
    (if (<= rand (car prop-list))
        (car name-list)
        (loop (cdr name-list) (cdr prop-list))))
  (loop inst-list prop))

(define inst-list (list (vector 'mul -1 -1) (vector 'clz -1 -1) (vector 'and -1 -1)))