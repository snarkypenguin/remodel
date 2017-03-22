; -*- mode: scheme; -*-

(define (sym->scm x) (let ((fn (string-append (symbol->string x) ".scm")))
							  ;;(display fn)(newline)
							  fn))

(for-each load (map sym->scm '(framework-flags preamble sort utils kdnl model-flags sclos)))
(include "framework") ;; must come before sclos+extn.scm

(for-each load (map sym->scm '(sclos+extn units constants maths)))
(for-each load (map sym->scm '(integrate matrix postscript basic-population)))
;; postscript should (logically) come after the mathematical files ... it uses matrices and such			 
(for-each load (map sym->scm '(framework-declarations framework framework-classes)))
(for-each load (map sym->scm '(introspection-classes monitor-classes log-classes)))
(for-each load (map sym->scm '(diffeq-classes landscape-classes plant-classes animal-classes)))
(for-each load (map sym->scm '(framework-wrappers declarations framework-methods)))
(for-each load (map sym->scm '(introspection-methods monitor-methods log-methods)))
(for-each load (map sym->scm '(diffeq-methods landscape-methods plant-methods animal-methods)))


;; The kernel alway comes last.
(load "kernel.scm")

(load "parameters.scm")

;-  The End 


;;; Local Variables: 
;;; comment-end: ""
;;; comment-start: "; "
;;; mode: scheme
;;; outline-regexp: ";-+"
;;; comment-column: 0
;;; End: