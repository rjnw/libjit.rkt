#lang racket

(require "spec.rkt"
         "pattern.rkt"
         (prefix-in rt: "runtime.rkt"))

(provide term-match-expander)

(define (pattern-expander stx pat)
  (fold-with-pattern pat stx))

(define (term-match-expander tt stx)
  (match-define (rt:term-type rt mt ss ts) tt)
  (syntax-case stx ()
    [(_ args ...)
     (match ss
       [(ast:node (ast:id nid-o nid-g nid-f) nargs pat ninfo)
        #`(#,nid-g md gargs #,(pattern-expander #`(args ...) pat))]
       [(ast:group (ast:id gid-o gid-g gid-f) prnt gargs nodes ginfo)
        (error 'sham:sam "todo match expander for group types: ~a" (car gid-o))])]))

(module+ test
  (require rackunit))
