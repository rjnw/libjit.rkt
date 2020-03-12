#lang racket

(require "core.rkt")
(require (for-syntax racket/syntax syntax/parse racket/pretty))

(provide (all-defined-out))

(define i1  (sham:ast:type:ref 'i1))
(define i8  (sham:ast:type:ref 'i8))
(define i16  (sham:ast:type:ref 'i16))
(define i32 (sham:ast:type:ref 'i32))
(define i64 (sham:ast:type:ref 'i64))

(define i8* (sham:ast:type:pointer i8))
(define i16* (sham:ast:type:pointer i16))
(define i32* (sham:ast:type:pointer i32))
(define i64* (sham:ast:type:pointer i64))

(define ui sham:ast:expr:const:ui)
(define (ui1 v) (sham:ast:expr:const:ui v i1))
(define (ui8 v) (sham:ast:expr:const:ui v i8))
(define (ui32 v) (sham:ast:expr:const:ui v i32))
(define (ui64 v) (sham:ast:expr:const:ui v i64))

(define si sham:ast:expr:const:si)
(define (si32 v) (sham:ast:expr:const:si v i32))
(define (si64 v) (sham:ast:expr:const:si v i64))

(define f32 (sham:ast:type:ref 'f32))
(define f64 (sham:ast:type:ref 'f64))
(define f32* (sham:ast:type:pointer f32))
(define f64* (sham:ast:type:pointer f64))

(define fl sham:ast:expr:const:fl)
(define (fl32 v) (sham:ast:expr:const:fl v f32))
(define (fl64 v) (sham:ast:expr:const:fl v f64))

(define tvoid (sham:ast:type:ref 'void))
(define (tvoid? x)
  (and (sham:ast:type:ref? x)
       (eq? (sham:ast:type:ref-to x) 'void)))

(define dmodule sham:def:module)
(define dfunction sham:def:function)
(define dtype sham:def:type)
(define dglobal sham:def:global)
(define dg-string sham:def:global-string)

(define tref sham:ast:type:ref)
(define tstruct sham:ast:type:struct)
(define tfun sham:ast:type:function)
(define tptr sham:ast:type:pointer)
(define tarr sham:ast:type:array)
(define tvec sham:ast:type:vector)

(define v4i32 (tvec i32 4))
(define v4i64 (tvec i64 4))
(define v4f32 (tvec f32 4))
(define v4f64 (tvec f64 4))

(define set!^ sham:ast:stmt:set!)
(define if^ sham:ast:stmt:if)
(define switch sham:ast:stmt:switch)
(define break sham:ast:stmt:break)
(define while sham:ast:stmt:while)
(define return sham:ast:stmt:return)
(define svoid sham:ast:stmt:void)
(define se sham:ast:stmt:expr)

(define app sham:ast:expr:app)
(define evoid sham:ast:expr:void)
(define sizeof sham:ast:expr:sizeof)
(define etype sham:ast:expr:etype)
(define gep sham:ast:expr:gep)
(define var sham:ast:expr:var)
(define v sham:ast:expr:var)
(define global sham:ast:expr:global)
(define external sham:ast:expr:external)
;; (define let sham:ast:expr:let) use let^

(define rs sham:ast:rator:symbol)

(define (re lib-id id ret-type (var-arg #f))
  (sham:ast:rator:external lib-id id ret-type var-arg))
(define rr sham:ast:rator:racket)

(define cfl sham:ast:expr:const:fl)
(define csi sham:ast:expr:const:si)
(define cui sham:ast:expr:const:ui)
(define cstring sham:ast:expr:const:string)
(define cllvm sham:ast:expr:const:llvm)
(define cstruct sham:ast:expr:const:struct)
(define carray sham:ast:expr:const:array)
(define cvector sham:ast:expr:const:vector)
(define (vec . vals) (sham:ast:expr:const:vector vals))

(define (return-void) (sham:ast:stmt:return (sham:ast:expr:void)))
(define (ret v) (sham:ast:stmt:return v))
(define (ret-void) (sham:ast:stmt:return (sham:ast:expr:void)))
(define (gep^ ptr . indexes) (gep ptr indexes))

;; internal function
(define (irs sym)
  (λ args (app (rs sym) args)))

(define icmp-eq (irs 'icmp-eq))
(define icmp-ne (irs 'icmp-ne))
(define icmp-ugt (irs 'icmp-ugt))
(define icmp-uge (irs 'icmp-uge))
(define icmp-ult (irs 'icmp-ult))
(define icmp-ule (irs 'icmp-ule))
(define icmp-sgt (irs 'icmp-sgt))
(define icmp-sge (irs 'icmp-sge))
(define icmp-slt (irs 'icmp-slt))
(define icmp-sle (irs 'icmp-sle))

(define fcmp-oeq (irs 'fcmp-oeq))
(define fcmp-ogt (irs 'fcmp-ogt))
(define fcmp-oge (irs 'fcmp-oge))
(define fcmp-olt (irs 'fcmp-olt))
(define fcmp-ole (irs 'fcmp-ole))
(define fcmp-one (irs 'fcmp-one))
(define fcmp-ord (irs 'fcmp-ord))
(define fcmp-uno (irs 'fcmp-uno))
(define fcmp-ueq (irs 'fcmp-ueq))
(define fcmp-ugt (irs 'fcmp-ugt))
(define fcmp-uge (irs 'fcmp-uge))
(define fcmp-ult (irs 'fcmp-ult))
(define fcmp-ule (irs 'fcmp-ule))
(define fcmp-une (irs 'fcmp-une))

(define add (irs 'add))
(define add-nsw (irs 'add-nsw))
(define add-nuw (irs 'add-nuw))
(define fadd (irs 'fadd))

(define sub (irs 'sub))
(define sub-nsw (irs 'sub-nsw))
(define sub-nuw (irs 'sub-nuw))
(define fsub (irs 'fsub))

(define mul (irs 'mul))
(define mul-nsw (irs 'mul-nsw))
(define mul-nuw (irs 'mul-nuw))
(define fmul (irs 'fmul))

(define udiv (irs 'udiv))
(define sdiv (irs 'sdiv))
(define exact-sdiv (irs 'exact-sdiv))
(define fdiv (irs 'fdiv))

(define urem (irs 'urem))
(define srem (irs 'srem))
(define frem (irs 'frem))

(define shl (irs 'shl))
(define lshr (irs 'lshr))
(define ashr (irs 'ashr))

(define or^ (irs 'or))
(define xor^ (irs 'xor))
(define and^ (irs 'and))
(define not^ (irs 'not))

(define malloc^ (irs 'malloc))
(define free^ (irs 'free))
(define arr-malloc (irs 'arr-malloc))
(define arr-alloca (irs 'arr-alloca))

;;casts
(define trunc  (irs 'trunc))
(define zext   (irs 'zext))
(define sext   (irs 'sext))
(define fp->ui (irs 'fp->ui))
(define fp->si (irs 'fp->si))
(define ui->fp (irs 'ui->fp))
(define si->fp (irs 'si->fp))
(define fp-trunc (irs 'fp-trunc))
(define fp-ext   (irs 'fp-ext))
(define ptr->int (irs 'ptr->int))
(define int->ptr (irs 'int->ptr))
(define bitcast  (irs 'bitcast))
(define addrspacecast (irs 'addrspacecast))
(define zextorbitcast (irs 'zextorbitcast))
(define sextorbitcast (irs 'sextorbitcast))
(define ptrcast  (irs 'ptrcast))
(define intcast  (irs 'intcast))
(define fpcast   (irs 'fpcast))

(define load (irs 'load))
(define store! (irs 'store!))


(define (while^ expr . stmts)
  (while expr (block stmts)))
(define (while-ule^ ind bound . stmts)
  (while (icmp-ule ind bound) (block stmts)))

;; intrinsics
(define (intrinsic . args)
  (define sargs (map symbol->string args))
  (define s. (string-join sargs "."))
  (string->symbol (format "llvm.~a" s.)))


(define-syntax (li stx)
  (syntax-parse stx
    [(_ names:id ...)
     (define sl (for/list ([name (syntax->list #`(names ...))])
                  (define fname (datum->syntax name (string->symbol (format "ri-~a" (syntax->datum name)))))
                  #`(define-syntax-rule
                      (#,fname iarg ret-type args #,'...)
                      (app (ri (intrinsic (quote #,name) (quote iarg)) ret-type) (list args #,'...)))))
     ;; (pretty-print (map syntax->datum sl))
     #`(begin #,@sl)]))

(li memcpy memmove memset sqrt powi sin cos pow exp exp2 log log10 log2 fma fabs
    minnum maxnum copysign floor ceil trunc rint nearbyint round bitreverse
    bswap ctpop ctlz cttz fshl fshr sadd.with.overflow uadd.with.overflow
    ssub.with.overflow usub.with.overflow smul.with.overflow umul.with.overflow
    canonicalize fmuladd)

(define ri sham:ast:rator:intrinsic)
(define-syntax-rule (ri^ intr ret-type args ...)
  (app^ (ri (intrinsic (quote intr)) ret-type) args ...))
(define-syntax (let^ stx)
  (syntax-parse stx
    [(_ ([arg val (~datum :) typ] ...) s:expr ... e:expr)
     #`(let ([arg (v (quasiquote arg))] ...)
         (sham:ast:expr:let (list (quasiquote arg) ...) (list typ ...) (list val ...)
                            (block^ s ...)
                            e))]))
(define-syntax (slet^ stx)
  (syntax-parse stx
    [(_ ([arg val (~datum :) typ] ...) s:expr ...)
     #`(let ([arg (v (quasiquote arg))] ...)
         (sham:ast:expr:let (list (quasiquote arg) ...) (list typ ...) (list val ...)
                            (block^ s ...)
                            (evoid)))]))
(define-syntax (switch^ stx)
  (syntax-parse stx
    [(_ v:expr [case:expr branch:expr] ... default)
     #`(switch v (list case ...) (list branch ...) default)]))

(define (block stmts)
  (sham:ast:stmt:block
   (map
    (λ (v) (cond [(sham:ast:expr? v) (se v)]
                 [(sham:ast:stmt? v) v]
                 [else (error "block expects a stmt/expr given: " v)]))
    stmts)))
(define (block^ . stmts) (block stmts))
(define (app^ rator . rands)
  (match rator
    [r #:when (sham:ast:rator? r) (app r rands)]
    [(sham:ast:expr:var md v) (app (rs v) rands)]
    ;; [h #:when (hfunction? h) (apply h rands)]
    [s #:when (symbol? s) (app (rs s) rands)]
    [else (error "expected rator for app^ given: " rator)]))

(define-syntax (function^ stx)
  (syntax-parse stx
    [(_ name:expr [(args:id (~datum :) arg-types:expr) ...] ret-type:expr body:expr ...)
     #`(dfunction #f name (list (quote args) ...) (list arg-types ...) ret-type
                  (let ([args (v (quote args))] ...)
                    (block^ body ...)))]))

;; metadata
(define (ast-set-metadata! ast md) (set-sham:ast-metadata! ast md))

;; fastcc
(require sham/env/infos)
(define (set-calling-conv! ast callc)
  (define orig-md (sham:ast-metadata ast))
  (define new-md
    (function-info-set-call-conv (if orig-md orig-md (basic-empty-info)) callc))
  (ast-set-metadata! ast new-md))
(define (fastcc! ast)
  (set-calling-conv! ast 'Fast)
  ast)
