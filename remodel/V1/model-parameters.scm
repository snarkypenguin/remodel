;-  Identification and Changes

;--
;	model-parameters.scm -- Written by Randall Gray 


;(if (member 'velociraptor model-list) (load "velociraptor-parameters.scm"))
(if (member 'seabed model-list) (load "seabed-parameters.scm"))
(if (member 'dinos model-list) (load "velociraptor-parameters.scm"))
(if (member 'savanna model-list) (load "savanna-parameters.scm"))


;; Now edit the *-init.scm file



;-  The End 


;;; Local Variables:
;;; mode: scheme
;;; outline-regexp: ";-+"
;;; comment-column:0
;;; comment-start: ";;; "
;;; comment-end:"" 
;;; End:
