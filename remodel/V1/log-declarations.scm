;-  Identification and Changes

(declare-method introspection-list "return the introspection list")
(declare-method set-introspection-list! "set the list of agents to be examined")
(declare-method introspection-times "return the introspection list")
(declare-method set-introspection-times! "set the list of agents to be examined")
(declare-method page-preamble "open files & such")
(declare-method log-this-agent "a lambda that produces output")
(declare-method page-epilogue "make things tidy")
(declare-method set-variables! "set the list of variables")
(declare-method extend-variables! "extend the list of variables")


(declare-method schedule-times "return a schedule")
(declare-method schedule-epsilon "return a schedule's epsilon")
(declare-method set-schedule-times! "set the times the agents is scheduled to do something")
(declare-method set-schedule-epsilon! "set the epsilon for the schedule")
(declare-method insert-schedule-time! "insert a time into a schedule")
;;(declare-method flush-stale-schedule-entries! "name says it all, really...")
;;(declare-method scheduled-now? "name says it all, really...")

(declare-method log-data "err, ...log data to an open output") 
(declare-method emit-page "set the list of agents to be examined")
(declare-method open-p/n "open a port for logging")
(declare-method close-p/n "close a logging port")


(declare-method map-log-track-segment "description needed")
(declare-method map-projection "description needed")
(declare-method set-map-projection! "description needed")
(declare-method map-log-data "specific for postscript output")
(declare-method map-emit-page "specific for postscript output")

(declare-method data-log-track-segment "description needed")
(declare-method data-log-data "specific for data output")
(declare-method data-emit-page "specific for data output")

;-  The End 


;;; Local Variables:
;;; mode: scheme
;;; outline-regexp: ";-+"
;;; comment-column:0
;;; comment-start: ";;; "
;;; comment-end:"" 
;;; End:
