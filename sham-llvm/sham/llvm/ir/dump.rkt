#lang racket

(require sham/llvm/ffi
         sham/llvm/ir/env)
(provide (all-defined-out))

(define (dump-llvm-module mod-env)
  (LLVMDumpModule (llvm-env-module-ref mod-env)))

(define (dump-llvm-function mod-env fsym)
  (LLVMDumpValue (llvm-env-lookup-value mod-env fsym)))

(define (write-llvm-bitcode mod-env file-name)
  (LLVMWriteBitcodeToFile (llvm-env-module-ref mod-env) file-name))

(define (write-llvm-module mod-env file-name)
  (match-define (vector error? error-message)
    (LLVMPrintModuleToFile (llvm-env-module-ref mod-env) file-name))
  (when error?
    (error 'sham:llvm "couldn't generate llvm module file: ~a, llvm-error: ~a" file-name error-message)))
