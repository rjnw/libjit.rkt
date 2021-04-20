#lang racket

(require syntax/parse
         racket/syntax
         (for-template racket racket/match))

(require (prefix-in rt: "runtime.rkt")
         "spec.rkt"
         "pattern.rkt")

(provide rkt-pattern-transformer
         rkt-match-expander)

#;(- there are three different options for providing macros for production nodes
     * generate a syntax macro for each production
     * write a conventional pattern matcher that performs
     * make use of racket's pattern matcher and convert our patterns to racket based on the storage format

     We use the third option here using fold-with-pattern which takes a pattern and syntax folds
     over the syntax according to the pattern)

(define (match-group-args gargs stxs)
  (match* (gargs stxs)
    [('() ss) (values '() ss)]
    [((cons gs grs) (cons ss srs))
     (define-values (gr sr) (match-group-args grs srs))
     (values (cons ss gr) sr)]
    [(_ _) (error 'sham/sam "not enough arguments for common group args")]))

(define (rkt-match-expander tt stx)
  (match-define (rt:term-type rt mt ss ts) tt)
  (syntax-parse stx
    [(_ (~optional (~seq (~datum #:md) md)) args ...)
     (match ss
       [(ast:node ids ninfo nargs pat)
        (define gs (find-node-group ss ts))
        (define gargs (full-group-args gs ts))
        (define-values (gargs-stx rest-stx) (match-group-args gargs (syntax-e #`(args ...))))
        (define nargs-stx (expand-with-pattern pat #`(#,@rest-stx)))
        #`(#,(ast:id-gen ids) (~? md _) (vector #,@gargs-stx) #,nargs-stx)]
       [(ast:group ids ginfo prnt gargs nodes)
        (define gargs (full-group-args ss ts))
        (define-values (gargs-stx rest-stx) (match-group-args gargs (syntax-e #`(args ...))))
        ;; (error 'sham:sam "todo match expander for group types: ~a" (ast:id-orig ids))
        #`(#,(ast:id-gen ids) (~? md _) (vector #,@gargs-stx) _)])]))

(define (rkt-pattern-transformer tt stx)
  (match-define (rt:term-type rt mt ss ts) tt)
  (match-define (ast tid tids grps info) ts)
  (syntax-parse stx
    [nid:id (get-struct-id (ast:basic-id ss))]
    [(_ (~optional (~seq (~datum #:md) md:expr)) args ...)
     (match ss
       [(ast:node ids ninfo nargs pat)
        (define gs (find-node-group ss ts))
        (define gargs (full-group-args gs ts))
        (define-values (gargs-stx rest-stx) (match-group-args gargs (syntax-e #`(args ...))))
        (define nargs-stx (expand-with-pattern pat #`(#,@rest-stx)))
        #`(#,(ast:id-gen ids) (~? md #f) (vector #,@gargs-stx) #,nargs-stx)]
       [(ast:group ids ginfo prnt gargs nodes)
        (define gargs (full-group-args ss ts))
        (define-values (gargs-stx rest-stx) (match-group-args gargs (syntax-e #`(args ...))))
        ;; (error 'sham:sam "todo match expander for group types: ~a" (ast:id-orig ids))
        #`(#,(ast:id-gen ids) (~? md #f) (vector #,@gargs-stx) (vector))])
     ;; #`(#,(get-struct-id nids) (~? md #f) (vector) #,(expand-with-pattern pat #`(args ...)))
     ]))
