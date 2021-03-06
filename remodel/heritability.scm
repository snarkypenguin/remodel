; -*- mode: scheme; -*-
;; <top> <primitive-object> <object> <agent> ...


(load "loadem.scm")
(include "remodel-framework")

;- Inheritance and chaining test rig


(define-class <C0> (inherits-from <agent>) (state-variables testcase1  testcase2))
(define-class <D0> (inherits-from <agent>) (state-variables testcase3))

(define-class <E0> (inherits-from <C0>) (state-variables testcase4))
(define-class <F0> (inherits-from <C0> <D0>) (state-variables testcase5))

(declare-method test "tests")

(model-method <C0> (test self #!rest args)
				  (dnl* 'CO-- self args)
				  (display "C0 ")(display args)(display ": ")
				  (display (slot-ref self 'testcase1))
				  (display " ")
				  (display (slot-ref self 'testcase2))
				  (newline)
				  'C0
				  )
(model-method <D0> (test self #!rest args)
				  (dnl* 'D0-- self args)
				  (display "D0 ")(display args)(display ": ")
				  (display (slot-ref self 'testcase3))
				  (newline)
				  (test-parent)
				  'D0
				  )

(model-method <E0> (test self #!rest args)
				  (dnl* 'E0-- self args)
				  (display "E0 ")
				  (display (slot-ref self 'testcase4))
				  (display " ")
				  (display (slot-ref self 'testcase2))
				  (display " ")
				  (display (slot-ref self 'testcase1))
				  (newline)
				  (test-parent)
				  'E0
				  )

(model-method <F0> (test self #!rest args)
				  (dnl* 'F0-- self args)
				  (dnl* "F0" (slot-ref self 'testcase5)
						  (slot-ref self 'testcase3) 
						  (slot-ref self 'testcase2) 
						  (slot-ref self 'testcase1))
				  (test-parent)
				  'F0
				  )


(model-body <C0>
				  (dnl* 'IC0-- self args)
				  (set-state-variables self args)
				  (slot-set! self 'testcase1 't1)
				  (slot-set! self 'testcase2 't2)
				(dnl "Cavorting in the common"))

(model-body <D0>
				  (dnl* 'ID0-- self args)
				  (set-state-variables self args)
				  (slot-set! self 'testcase3 't3)
				(dnl "Dancing in the diner"))

(model-body <E0>
				(dnl* 'IE0-- self args)
				(set-state-variables self args)
				(slot-set! self 'testcase4 't4)
				(dnl "Escalating"))
								

(model-body <F0>
				(dnl* 'IF0-- self args)
				(set-state-variables self args)
				(slot-set! self 'testcase5 't5)
				(dnl "flying fish")_)


(dnl "Defining Rob")
(define Rob (make-agent <F0> "testcase5" 'Crivens! 'needs-parent-initialisers (list <agent> <F0>)))
(dnl "Defining Hamish")
(define Hamish (make-agent <E0> "testcase3" "Nae King nor Quin!"))
(dnl "Defining Callan")
(define Callan (make-agent <C0> "testcase1" "Gie orf!"))
(dnl "Defining Dimo")
(define Dimo (make-agent <D0> "testcase3" "Ho YEZ!"))

(display "Rob Hamish Callan Dimo\n")

;;; (define c ((compute-methods test) (list Rob))) ;;;
;;; ((cadr (map method-procedure c)) (lambda x x) Rob) ;;;
;;; ((method-procedure (cadr c)) (lambda x x) Rob) ;;;

;;; ((method-procedure (car ((compute-methods test) (list Rob)))) (lambda x x) Rob) ;;;
;;; ((method-procedure (cadr ((compute-methods test) (list Rob)))) (lambda x x) Rob) ;;;
;;; ((method-procedure (caddr ((compute-methods test) (list Rob)))) (lambda x x) Rob) ;;;


;; (map (lambda (m) ((method-procedure m) Rob Rob)) ((compute-methods test) (list Rob)))
;; (map (lambda (m) ((method-procedure m) Rob Rob)) ((compute-methods test) (list Rob)))


;-  The End 


;;; Local Variables: 
;;; comment-end: " ;;;" ;;;
;;; comment-start: ";;; " ;;;
;;; mode: scheme ;;;
;;; outline-regexp: ";-+" ;;;
;;; comment-column: 0 ;;;
;;; End:
