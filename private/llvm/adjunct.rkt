#lang racket

(require ffi/unsafe
         "build-adjunct.rkt"
         "ffi/ctypes.rkt"
         "ffi/target-machine.rkt"
         "ffi/execution-engine.rkt")

(provide LLVMCreateMCJITCompilerForModuleWithTarget
         LLVMCreateCurrentTargetMachineRef)

(define LLVMCreateMCJITCompilerForModuleWithTarget
  (get-ffi-obj "LLVMCreateMCJITCompilerForModuleWithTarget"
               adjunct-lib
               (_fun (ee : (_ptr o LLVMExecutionEngineRef))
                     (mod : LLVMModuleRef)
                     (options : (_ptr i _LLVMMCJITCompilerOptions))
                     (err : (_ptr o _string))
                     -> (status : LLVMBool)
                     -> (values ee status err))))


(define LLVMCreateCurrentTargetMachineRef
  (get-ffi-obj "LLVMCreateCurrentTargetMachineRef"
               adjunct-lib
               (_fun -> LLVMTargetMachineRef)))