#lang racket

(require ffi/unsafe
         sham/llvm
         sham/ast/core
         sham/env)

(provide compile-type
         build-env-type
         register-initial-types
         internal-type-racket
         internal-type-llvm
         vector-type?)

(struct internal-type (racket llvm) #:prefab)

;;returns one of env-type object
(define (build-env-type t env #:name (type-name #f))
  (env-type t (compile-type t env #:name type-name)))

(define (compile-type t-obj env #:name (type-name #f))
  (match t-obj
    [(sham:ast:type:ref _ t) (env-type-prim (env-lookup t env))]
    [(sham:ast:type:struct _ names types)
     (create-struct-type (map (curryr compile-type env) types) #:name type-name)]
    [(sham:ast:type:function _ args ret)
     (create-function-type (map (curryr compile-type env) args)
                           (compile-type ret env))]
    [(sham:ast:type:pointer _ to)
     (create-pointer-type (compile-type to env))]
    [(sham:ast:type:array _ of size)
     (create-array-type (compile-type of env) size)]
    [(sham:ast:type:vector _ of size)
     (create-vector-type (compile-type of env) size)]))


;input internal-type
(define (create-function-type args ret)
  (define (create-racket-function-type args ret)
    (_cprocedure (map internal-type-racket args)
                 (internal-type-racket ret)))
  (define (create-llvm-function-type args ret)
    (LLVMFunctionType (internal-type-llvm ret) (map internal-type-llvm args) #f))
  (internal-type
   (create-racket-function-type args ret)
   (create-llvm-function-type args ret)))

(define (create-struct-type types #:name (type-name #f))
  (define (create-racket-struct-type types)
    _pointer)
  (define (create-llvm-struct-type types)
    (if type-name
        (let ([fields (map internal-type-llvm types)]
              ;; todo move this to when compiling declaration for recursive struct types
              [type (LLVMStructCreateNamed (if (string? type-name) type-name (symbol->string type-name)))])
          (LLVMStructSetBody type fields #t)
          type)
        (LLVMStructType (map internal-type-llvm types) #t)))
  (internal-type
   (create-racket-struct-type types)
   (create-llvm-struct-type types)))

(define (create-array-type type size) ;; size should be a nat
  (define llvm-array-type (LLVMArrayType (internal-type-llvm type) size))
  (define racket-array-type _pointer);; (_array/list (internal-type-racket type) size)

  (internal-type racket-array-type llvm-array-type))

(define (create-vector-type type size) ;; size should be a nat
  (define llvm-vector-type (LLVMVectorType (internal-type-llvm type) size))
  (define racket-vector-type _pointer);(_array/vector (internal-type-racket type) size))
  (internal-type racket-vector-type llvm-vector-type))

(define (create-pointer-type type)
  (define (create-racket-pointer-type type)
    _pointer)
  (define (create-llvm-pointer-type type)
    (LLVMPointerType (internal-type-llvm type) 0))
  ;; (printf "type ~a llvm-type ~a\n" type (internal-type-llvm type))
  (internal-type
   (create-racket-pointer-type type)
   (create-llvm-pointer-type type)))

;TODO add couple more pointer types for basic types
(define (register-initial-types env context)
  (define (register-types types)
    (for/fold [(env env)]
              [(t types)]
      (env-extend (first t)
                  (env-type (sham:ast:type:internal)
                            (internal-type (third t) (second t)))
                  env)))
  (define type-void*
    (env-type (sham:ast:type:pointer 'void)
              (internal-type  _pointer
                              (LLVMPointerType (LLVMInt8TypeInContext context) 0))))
  (define new-env
    (register-types
     `((i1 ,(LLVMInt1TypeInContext context) ,_uint)
       (i8 ,(LLVMInt8TypeInContext context) ,_uint8)
       (i16 ,(LLVMInt16TypeInContext context) ,_uint16)
       (i32 ,(LLVMInt32TypeInContext context) ,_uint32)
       (i64 ,(LLVMInt64TypeInContext context) ,_uint64)
       (i128 ,(LLVMInt128TypeInContext context) ,_ullong)
       (f32 ,(LLVMFloatTypeInContext context) ,_float)
       (f64 ,(LLVMDoubleTypeInContext context) ,_double)
       (void ,(LLVMVoidTypeInContext context) ,_void))))
  (env-extend 'void* type-void* new-env))



(define native-int-types (set _int _uint _sbyte _ubyte _short _ushort _long _ulong))
(define (type-native-int? envtype)
  (match envtype
    [(env-type _ (internal-type racket-type llvm-type))
     (set-member? native-int-types racket-type)]
    [else #f]))

(define (type-float32? envtype)
  (match envtype
    [(env-type _ (internal-type racket-type llvm-type))
     (equal? _float racket-type)]
    [else #f]))

(define (vector-type? t env)
  (match t
    [(sham:ast:type:ref _ t) (vector-type? (env-lookup t env))]
    [(sham:ast:type:vector _ _ _) #t]
    [else #f]))

(define (racket-type-cast object from-type to-type)
  (cast object
        (internal-type-racket (env-type-prim from-type))
        (internal-type-racket (env-type-prim to-type))))


(module+ test
  (require rackunit)
  (display 'env0)
  (define env0 (register-initial-types (empty-env) (LLVMGetGlobalContext)))
  (display 'env0)
  (define f64 (sham:ast:type:ref 'f64))
  (define  i32 (sham:ast:type:ref 'i32))
  (printf "env0: ~a\n" env0)
  (define env1 (env-extend 'double*
                              (build-env-type (sham:ast:type:pointer f64)  env0)
                              env0))
  (define env2 (env-extend 'sp
                           (build-env-type (sham:ast:type:struct '(a b)
                                                             (list i32 i32))
                                           env1)
                           env1))
  (define new-env1 (env-extend 'array-real
                               (build-env-type (sham:ast:type:struct '(size data) (list i32 i32)) env2)
                               env2))
  (pretty-print new-env1)
  (pretty-display (build-env-type (sham:ast:type:pointer i32) env0))
  (pretty-display (build-env-type (sham:ast:type:function (list i32) i32) env0))
  (define new-env (env-extend 'intref (build-env-type (sham:ast:type:ref 'i32) env0) env0))
  (pretty-display (type-native-int? (env-lookup 'i32 new-env)))
  (pretty-display (type-native-int? (env-lookup 'intref new-env)))
  (pretty-display (type-native-int? (env-lookup 'void* new-env)))
  (pretty-display (type-float32? (env-lookup 'f32 new-env))))
