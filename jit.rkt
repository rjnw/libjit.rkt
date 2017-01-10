#lang racket
(require ffi/unsafe)
(require "libjit.rkt")
(require "jit-env.rkt")
(require "jit-type.rkt")
(require "jit-intr.rkt")
(provide compile-module
         create-jit-context
         create-initial-environment
         context)

(define empty-label (jit_uint_not 0))

(struct context (jit env))

(define (create-jit-context)
  (jit_context_create))
(define global-jit-context (create-jit-context))

(define (create-initial-environment)
  (register-jit-internals (register-initial-types (empty-env))))
(define global-environment (create-initial-environment))
(define global-context (context global-jit-context global-environment))

(define (get-jit-function-pointer fobj)
  (jit_function_to_closure fobj))

(define (jit-get-function f)
  (match f
    [(env-jit-function type object cpointer)
     (racket-type-cast cpointer type-void* type)]))

(define (create-value value type function env)
  (define envtype (env-lookup type env))
  (define prim-type (type-prim-jit (env-type-prim envtype)))
  (cond [(or (type-native-int? envtype)
             (type-pointer? (env-type-skel envtype)))
         (jit_value_create_nint_constant
          function
          prim-type
          value)]
        [(type-float32? type)
         (jit_value_create_float32_constant
          function
          prim-type
          value)]
        [else (error "value type not supported yet!" value type)]))

(define (compile-lhs-assign lhs exp-value function env)
  (match lhs
    [(? symbol?)
     (define lhs-v (env-jit-value-v (env-lookup lhs env)))
     (jit_insn_store function lhs-v exp-value)]
    [`(* ,ptr ,off) ;off should be number of bytes, we don't do pointer arithmatic
     (define ptr-value (compile-expression ptr function env))
     (define off-value (compile-expression off function env))
     (define ptr-with-off (jit_insn_add function ptr-value off-value))
     (jit_insn_store_relative function ptr-with-off 0 exp-value)]
    [else (error "not implemented" lhs)]))

(define (compile-lhs-expression exp function env)
  (match exp
    [(? symbol?) (env-jit-value-v (env-lookup exp env))]
    [`(* ,ptr ,off : ,type) ;; again off is in bytes
     (define value-type (type-prim-jit
                       (env-type-prim
                        (env-lookup type env))))
     (define ptr-value (compile-expression ptr function env))
     (define off-value (compile-expression off function env))
     (define ptr-with-off (jit_insn_add function ptr-value off-value))
     (jit_insn_load_relative function ptr-with-off 0 value-type)]
    [else (error "not implemented lhs expression" exp)]))

(define (compile-app rator rand-values function env)
  (match (env-lookup rator env)
    [(env-jit-function type object cpointer)
     (jit_insn_call function "" object (type-prim-jit (env-type-prim type)) rand-values 0)]
    [(env-jit-function-decl type object)
     (jit_insn_call function "" object (type-prim-jit (env-type-prim type)) rand-values 0)]
    [(env-jit-internal-function compiler)
     (compiler function rand-values)]
    [(env-racket-function type f)
     ;TODO
     (error "not implemented applicative")]
    [(env-racket-ffi-function type f)
     ;TODO
     (error "not implemented applicative")]
    [(env-c-function type f)
     (jit_insn_call_native function #f f type rand-values 0)]
    [else (error "rator ~a\n" (env-lookup rator env))]))

;; returns an object of jit_value
(define (compile-expression exp function env)
  (printf "compiling expression ~a\n" exp)
  (match exp
    [`(#%app ,rator ,rands ...)
     (define rand-values
       (for/list ([rand rands])
         (compile-expression rand function env)))
     (compile-app rator rand-values function env)]
    [`(#%value ,value ,type) (create-value value type function env)]
    [`(#%sizeof ,type)
     (define envtype (env-lookup type env))
     (create-value (jit_type_get_size (type-prim-jit (env-type-prim envtype)))
                   'uint function env)] 
    [else (compile-lhs-expression exp function env)]))

;; returns void
(define (compile-statement stmt function env)
  (printf "compiling statement ~a\n" stmt)
  (match stmt
    [`(define-variable (,id : ,type) ,st)
     (define id-type (env-lookup type env))
     (define id-value (jit_value_create function (type-prim-jit (env-type-prim id-type))))
     (compile-statement st function (env-extend id (env-jit-value id-value id-type) env))]
    [`(assign ,lhs ,v)
     (define exp-value (compile-expression v function env))
     (compile-lhs-assign lhs exp-value function env)]
    [`(if ,tst ,thn ,els)
     (define tst-value (compile-expression tst function env))
     (define label-if (jit_insn_branch_if function tst-value empty-label))
     (compile-statement els function env)
     (define label-end (jit_insn_branch function empty-label))
     (jit_insn_label function label-if)
     (compile-statement thn function env)
     (jit_insn_label function label-end)]
    [`(while ,tst ,body)
     (define start-label (jit_insn_label function empty-label))
     (define tst-value (compile-expression tst function env))
     (define end-label (jit_insn_branch_if_not function tst-value empty-label))
     (compile-statement body function env)
     (jit_insn_branch function start-label)
     (jit_insn_label function end-label)]
    [`(return ,exp) (jit_insn_return function (compile-expression exp function env))]
    [`(return-tail ,exp) (jit_insn_return function (compile-expression exp function env))];;TODO
    [`(block ,stmts ...)
     (for ([stmt stmts])
       (compile-statement stmt function env))]
    [`(#%exp ,e)
     (compile-expression e function env)]
    [else (error "unknown statement or not implemented")]))

(define (compile-function-definition name args types ret-type body f-decl env context)
  (define fobject (env-jit-function-decl-object f-decl))
  (define ftype (env-jit-function-decl-type f-decl))
  (define jitc (context-jit context))
  (jit_context_build_start jitc)
  (define new-env
    (for/fold ([env env])
             ([arg args]
              [type types]
              [i (in-range (length args))])
      (env-extend arg (env-jit-value (jit_value_get_param fobject i) type) env)))
  (compile-statement body fobject new-env)
  (jit_function_compile fobject)
  (jit_context_build_end jitc)
  (env-jit-function ftype fobject (get-jit-function-pointer fobject)))

(define (compile-function-declaration function-type context)
  (define sig (type-prim-jit (env-type-prim function-type)))
  (jit_context_build_start (context-jit context))
  (define function-obj (jit_function_create (context-jit context) sig))
  (jit_context_build_end (context-jit context))
  function-obj)

;; returns a binding of all the define-function as an assoc list
;; TODO support recursive struct types
(define (compile-module m [context global-context])
  (define (register-module-statement stmt env)
    (match stmt
      [`(define-type ,type-name ,t)
       (define type-decl (compile-type-declaration stmt env))
       (define type (compile-type-definition type-decl env))
       (env-extend type-name type env)]
      [`(define-function (,function-name (,args : ,types) ... : ,ret-type) ,body)
       (define type (create-type `(,@types -> ,ret-type) env))
       (define function-obj (compile-function-declaration type context))
       (env-extend function-name (env-jit-function-decl type function-obj) env)]))

  (define (compile-module-statement stmt env module-env)
    (match stmt
      [`(define-type ,type-name ,t)
       ;types are created in register phase; something for recursive struct types to be done
       (env-extend type-name (env-lookup type-name env) module-env)]

      [`(define-function (,function-name (,args : ,types) ... : ,ret-type) ,body)
       (define f (compile-function-definition function-name args types ret-type body
                                              (env-lookup function-name env) env context))
       (env-extend function-name f module-env)]))

  (match m
    [`(module ,module-stmts ...)
     (define env
       (for/fold ([env (context-env context)])
                 ([stmt module-stmts])
         (register-module-statement stmt env)))
     (for/fold ([module-env (empty-env)])
               ([stmt module-stmts])
       (compile-module-statement stmt env module-env))]))

(module+ test
  (require rackunit)
  (define module-env
   (compile-module
    '(module
         (define-type bc (struct (b : int) (c : int)))
         (define-type pbc (pointer bc))
       (define-type ui (struct (bc1 : pbc) (bc2 : pbc)))

       (define-function (f (x : int) : int)
         (return (#%app jit-add x x)))

       (define-function (even? (x : int) : int)
         (if (#%app jit-eq? (#%app jit-rem x (#%value 2 int)) (#%value 0 int))
             (return (#%value 1 int))
             (return (#%value 0 int))))

       (define-function (meven? (x : int) : int)
         (if (#%app jit-eq? x (#%value 0 int))
             (return (#%value 1 int))
             (return (#%app modd? (#%app jit-sub x (#%value 1 int))))))

       (define-function (modd? (x : int) : int)
         (if (#%app jit-eq? x (#%value 0 int))
             (return (#%value 0 int))
             (return (#%app meven? (#%app jit-sub x (#%value 1 int))))))
       (define-function (fact (x : int) : int)
         (if (#%app jit-eq? x (#%value 0 int))
             (return (#%value 1 int))
             (return (#%app jit-mul
                     x
                     (#%app fact
                            (#%app jit-sub x (#%value 1 int)))))))
       (define-function (factr (x : int) : int)
         (define-variable (result : int)
           (block
            (assign result (#%value 1 int))
            (define-variable (i : int)
              (block
               (assign i (#%value 1 int))
               (while (#%app jit-le? i x)
                 (block
                  (assign result (#%app jit-mul result i))
                  (assign i (#%app jit-add i (#%value 1 int)))))
               (return result))))))
       (define-function (malloc-test  : int)
         (define-variable (ptr : void*)
           (define-variable (x : int)
             (block
              (assign ptr (#%app jit-malloc (#%sizeof int)))
              (assign (* ptr (#%value 0 int)) (#%value 8 int))
              (assign x (* ptr (#%value 0 int) : int))
              (#%exp (#%app jit-free ptr))
              (return x)))))
       (define-type int* (pointer int))

       (define-function (sum-array (arr : int*) (size : int) : int)
         (define-variable (i : int)
           (define-variable (sum : int)
             (block
              (assign i (#%value 0 int))
              (assign sum (#%value 0 int))
              (while (#%app jit-lt? i size)
                (block
                 (assign sum (#%app jit-add
                                    sum
                                    (* arr (#%app jit-mul i (#%sizeof int)) : int)))
                 (assign i (#%app jit-add i (#%value 1 int)))))
              (return sum)))))

       (define-type ulong* (pointer ulong))
       (define-function (dot-product (arr1 : ulong*) (arr2 : ulong*) (size : ulong) : ulong)
         (define-variable (sum : ulong)
           (define-variable (i : ulong)
             (block
              (assign i (#%value 0 ulong))
              (assign sum (#%value 0 ulong))
              (while (#%app jit-lt? i size)
                (define-variable (ptr-pos : int)
                  (block
                   (assign ptr-pos (#%app jit-mul i (#%sizeof ulong)))
                   (assign sum (#%app jit-add
                                      sum
                                      (#%app jit-mul
                                             (* arr1 ptr-pos : ulong)
                                             (* arr2 ptr-pos : ulong))))
                   (assign i (#%app jit-add i (#%value 1 ulong))))))
              (return sum)))))
       )))
  (define f (jit-get-function (env-lookup 'f module-env)))
  (pretty-print (f 21))
  (define even? (jit-get-function (env-lookup 'even? module-env)))
  (pretty-print (even? 42))
  (define meven? (jit-get-function (env-lookup 'meven? module-env)))
  (pretty-print (meven? 21))

  (define fact (jit-get-function (env-lookup 'fact module-env)))
  (pretty-print (fact 5))
  (define factr (jit-get-function (env-lookup 'factr module-env)))
  (pretty-print (factr 5))
  (define malloc-test (jit-get-function (env-lookup 'malloc-test module-env)))
  (malloc-test)
  (define sum-array (jit-get-function (env-lookup 'sum-array module-env)))
  (define biglist (stream->list (in-range 100000)))
  (define bigarray (list->cblock biglist _ulong))
  ;; (sum-array bigarray (length biglist))

  (define dot-product (jit-get-function (env-lookup 'dot-product module-env)))
  (time (dot-product bigarray bigarray (length biglist)))
  (time
   (for/sum [(a1 biglist)
             (a2 biglist)]
     (* a1 a2)))
  )