#lang racket

(require "ir/ast.rkt"
         sham/sam/id)

(struct context [current bindings])

(define ((register-in-context ctxt decl) val)
  (define id (post:decl-id decl))
  ;; check val and add to appropriate map
  (match-define (context crnt bnds) ctxt)
  (context crnt (id-binding-map-add bnds id val)))
(define (to-module-context . args) 'TODO)
(define (to-instance-context . args) 'TODO)
(define (do-register-in-context ctxt id val)
  (values val (register-in-context ctxt id val)))
(define (lookup-identifier id ctxt) 'TODO)

(struct ivalue [])
(struct idecl ivalue [id])
(struct ideclmod idecl [isig idecls])
(struct ideclclass idecl [iargs ifields])
(struct ideclval idecl [itype interpretf])

(struct iexpr ivalue [])
(struct idata iexpr [subtype ifields])
(struct ilit iexpr [itype value])

(struct itype [type ctxt])

(define-compiler (interpret-post [ctxt (initial-context)]
                                 [type #f])
  (post:decl:mod -> rkt)
  (cdecl (decl -> def)
         #:after ([ctxt <= (register-in-context ctxt decl)])
         [(post:decl:mod id (^ sig) ds ...)
          (with ([ctxt (to-module-context ctxt id sig)])
                (compile ([(ds^ ...) (ds ...)])
                         (ideclmod id sig (build-decl-map ds^))))]
         [(post:decl:typ id (^ type)) (idecltype id type)]
         [(post:decl:val id (^ type) (^ body)) (ideclvalue id type body)])
  (cexpr (expr -> any)
         [(post:expr:var id) (lookup-identifier id ctxt)]
         [(post:expr:app op args ...) TODO]
         [(post:expr:data (^ typ otyp) fields ...)
          (compile ([(fields^ ...) #:for ([(ftyp ...) (data-type-fields typ)])
                                   (with ([type ftyp]) (fields ...))])
                   (idata (lookup-subtype type otyp) (ie fields)))]
         [(post:expr:anno val (^ typ))
          (compile ([val^ (with ([type typ]) val)])
                   val^)]
         [(post:expr:case (args ...) (pats ... body) ... dflt) TODO]
         [(post:expr:lam (args ...) body) TODO]
         [(post:expr:lit (^ typ) val) (ilit typ val)] )
  (ctype (type -> any)
         [(post:type:sig (fld typ) ...)]
         [(post:type:adt (subi subt ...) ...)]
         [(post:type:fun args ... ret)]
         [(post:type:lit sham check coerce)]))
