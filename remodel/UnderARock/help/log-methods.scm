;-  Identification and Changes



"In the logging code, a 'page' is notionally a pass through the target
agent list.  The page-preamble may open a file and write some
preliminary stuff, or it may just assume that the file is open already
and do nothing at all.  Similarly the page-epilogue does things like
close pages and emit 'showpage' for postscript stuff.
"




(define introspection-priority 10000)

(define (schedule-times self class-sym)
  (if (eq? class-sym 'introspection) (schedule-times self T 'timestep)
		(slot-ref self
					 (string->symbol
					  (string-append (symbol->string class-sym) "schedule")))))

(define (schedule-epsilon self class-sym)
  (if (eq? class-sym 'introspection) (schedule-epsilon self T 'timestep)
		(slot-ref self
					 (string->symbol
					  (string-append
						(symbol->string class-sym)
						"epsilon")))))

(define (set-schedule-times! self class-sym lst)
  (if (eq? class-sym 'introspection) (set-schedule-times! self T 'timestep)
		(slot-set! self (string->symbol (string-append (symbol->string class-sym)
																	  "schedule")) lst)))

(define (insert-schedule-time! self class-sym t)
  (if (eq? class-sym 'introspection) (insert-schedule-time! self T 'timestep)
		(slot-set! self (string->symbol (string-append (symbol->string class-sym)
																	  "schedule"))
					  (uniq (sort (cons t (schedule-times self class-sym)) <=)))))

(define (set-schedule-epsilon! self class-sym val)
  (if (eq? class-sym 'introspection) (set-schedule-epsilon! self T 'timestep)
		(slot-set! self (string->symbol (string-append (symbol->string class-sym)
																	  "epsilon"))
					  val)))


(define (flush-stale-schedule-entries! self class-sym)
  (if (eq? class-sym 'introspection)
		(flush-stale-schedule-entries! self T 'timestep)
		(let ((cs-sym (string->symbol (string-append
												 (symbol->string class-sym) "-schedule")))
				(ce-sym (string->symbol (string-append
												 (symbol->string class-sym) "-epsilon"))))
		  (slot-set! self
						 cs-sym
						 (filter (lambda (x) (> (+ x (slot-ref self ce-sym))
														(slot-ref self 'subjective-time))
											  )
									(slot-ref self cs-sym))))) )


(define (scheduled-now? self T class-sym)	
  (if (eq? class-sym 'introspection)
		(scheduled-now? self T 'timestep)
		(let ((cs-sym (string->symbol (string-append
												 (symbol->string class-sym)
												 "-schedule")))
				(ce-sym (string->symbol (string-append
												 (symbol->string class-sym)
												 "-epsilon"))))
		  (kdnl* '(log-sched-error) "[Getting" cs-sym " = " (slot-ref self cs-sym)
					" and " ce-sym " = " (slot-ref self ce-sym))
		  (let ((sched (slot-ref self cs-sym)))
			 (let ((v (not (or
								 (null? sched)
								 (zero?
								  (length
									(filter 
									 (lambda (x)
										(<= (abs (- T x)) (slot-ref self ce-sym)))
									 sched)))))))
				(flush-stale-schedule-entries! self class-sym)
				v)))))

(define (introspection-filename filename filetype #!optional t)
  (if (string? filename)
		(if t
			 (string-append filename "-" (pno t 6) "0" filetype)
			 (string-append filename filetype))
		#f))





(model-method <agent> (map-projection self)
 				  (my 'map-projection))

(model-method (<agent> <procedure>) (set-map-projection! self p)
				  (set-my! 'map-projection p))

;; Logger agents (things that inherit from introspection, really) have
;; a high priority; as a consequence they get sorted to the front of a
;; timestep
(add-method
 initialize
 (make-method (list <introspection>)
				  (lambda (initialize-parent self args)
					 ;;(dnl "<thing> init")
					 (initialise self (list 'type 'introspection
													'priority introspection-priority
													'jiggle 0 'introspection-list '() 
													'timestep-epsilon 1e-6 'file #f
													'filename #f 'filetype #f
													'format 'text 'missing-val "NoData"
													'show-field-name #f 'preamble-state '()
													'variables-may-be-set #t
													))
					 (initialize-parent) ;; call "parents" last to make the
												;; initialisation list work
					 (initialise self args)
					 )))

(model-method <introspection> (agent-prep self start end kernel . args)
				  (agent-prep-parent)
				  )

(model-method <introspection> (agent-shutdown self . args)
				  (let ((file (my 'file)))
					 (if (and (my 'file)
								 (output-port? (my 'file))
								 (not (memq (my 'file)
												(list (current-output-port)
														(current-error-port)))))
						  (close-output-port file))
					 (set-my! 'file #f)
					 (agent-shutdown-parent)
					 ))

(model-body <introspection>

						(kdnl* '(log-* introspection-trace)
								 "[" (my 'name) ":" (class-name-of self) "]"
								 "Introspection: model-body")

						(let ((sched (my 'timestep-schedule))
								)

						  (set! dt (if (and (pair? sched) (< (car sched) (+ t dt)))
											(- (car sched) t)
											dt))

						  (kdnl* '(log-* introspection-trace)
									"      list:     " (my 'introspection-list))
						  (kdnl* '(log-* introspection-trace)
									"      schedule: "
									(list-head (my 'timestep-schedule) 3)
									(if (> (length (my 'timestep-schedule)) 3)
										 '... ""))
						  
						  (set-my! 'variables-may-be-set #f)
						  (emit-page self)

						  ;(skip-parent-body)
						  (parent-body)
						  ;;(max dt (* 2.0 dt))
						  dt
						))



(model-method (<introspection> <agent>) (insert-agent! self target)
				  (set-my! 'introspection-list (cons target
																 (my 'introspection-list))))

(model-method (<introspection> <agent>) (append-agent! self target)
				  (set-my! 'introspection-list (append (my 'introspection-list)
																	(list target))))

(model-method <introspection> (introspection-list self)
				  (my 'introspection-list))
(model-method <introspection> (introspection-times self)
				  (my 'timestep-schedule))

(model-method (<introspection> <list>) (set-introspection-list! self lst)
				  (set-my! 'introspection-list lst))				  
(model-method (<introspection> <list>) (set-introspection-times! self lst)
				  (set-my! 'timestep-schedule lst))

(model-method (<introspection> <list>) (set-variables! self lst)
				  (if (and (my 'variables-may-be-set) (list? lst))
						(set-my! 'variables lst)
						(abort "cannot extend variables after it starts running")
						))

(model-method (<introspection> <list>) (extend-variables! self lst)
				  (if (and (my 'variables-may-be-set) (list? lst))
						(set-my! 'variables (unique* (append (my 'variables) lst)))
						(abort "cannot extend variables after it starts running")
						))
(define (cnc a) (class-name-of (class-of a)))
(define (nm? a) (if (isa? a <agent>) (slot-ref a 'name) a))

(model-method (<introspection>) (emit-page self)
				  (kdnl* '(log-* introspection-trace)
							"[" (my 'name) ":" (class-name-of self) "]"
							"Introspection: emit-page")
				  (let ((format (my 'format)))
					 (page-preamble self self format) ;; for snapshots,
																 ;; this will be
																 ;; "opening", for
																 ;; logfiles, it will
																 ;; only open the
																 ;; first time

					 (for-each 
					  (lambda (ila)
						 (kdnl* '(log-* introspection-trace) "   processing "
								  (cnc ila) " "  (procedure? ila))
						 (log-data ila self format self (my 'variables))
						 #f
						 )
					  (my 'introspection-list))
					 )
				  (page-epilogue self self (slot-ref self 'format))
				  )


;---- snapshot methods

(model-method <snapshot> (initialize self args)
				  (initialize-parent) ;; call "parents" last to make the
											 ;; initialisation list work
				  (initialise self (list 'type snapshot 'lastfile #f
												 'currentfile #f))
				  (initialise self args)
				  )

(use-parent-body <logfile>)


(model-method <snapshot> (page-preamble self logger format)
				  (kdnl* '(introspection snapshot)"[" (my 'name) ":"
							(class-name-of self) "]" "is preparing to dump")
				  (let ((filename (my 'filename))
						  (filetype (my 'filetype))
						  (file (my 'file))
						  (t (my 'subjective-time))
						  )

					 (cond
					  ((not (or (not filename) (string? filename)))
						(error (string-append (my 'name)" has a filename which "
													 "is neither false, nor a string.")))

					  ((not (or (not filetype) (string? filetype)))
						(error (string-append (my 'name) " has a filetype which "
													 "is neither false, nor a string.")))

					  ((not (number? t))
						(error (string-append (my 'name) " has a subjective time "
													 "which is not a number.")))
					  )

					 ;; Open a new file
					 (cond
					  ((not file)
						(let ((fn (introspection-filename (my 'filename)
																	 (my 'filetype) t)))
						  (kdnl* '(introspection snapshot) "[" (my 'name) ":"
									(class-name-of self) "]" "opening" fn)
						  (set-my! 'lastfile (my 'currentfile))
						  (set-my! 'currentfile fn)
						  (if (zero? (string-length fn))
								(set! file (current-output-port))
								(set! file (open-output-file fn)))
						  ))
					  ((memq file (list (current-output-port) (current-error-port)))
						;; do nothing really
						(kdnl* '(introspection snapshot) "[" (my 'name) ":"
								 (class-name-of self) "]"
								 "is writing to stdout or stderr")
						#!void
						)
					  (else 
						(kdnl* '(introspection  snapshot) "[" (my 'name) ":"
								 (class-name-of self) "]" " "
								 "has hit page-preamble with a file that is still open."
								 "\nThis is an error.\nClosing the file ("
								 (my 'lastfile) ") and continuing.")
						(close-output-port file)
						(set-my! 'file #f)
						(let ((fn (introspection-filename (my 'filename)
																	 (my 'filetype) t)))
						  (set-my! 'lastfile (my 'currentfile))
						  (set-my! 'currentfile fn)
						  (if (zero? (string-length fn))
								(set! file (current-output-port))
								(set! file (open-output-file fn)))
						  )
						)
					  )
					 (set-my! 'file file)))

(model-method <snapshot> (page-epilogue self logger format)
				  (let ((file (my 'file)))
					 (if (and file (not (memq file (list (current-output-port)
																	 (current-error-port)))))
						  (begin
							 (kdnl* '(introspection snapshot) "[" (my 'name) ":"
									  (class-name-of self) "]"
									  "is closing the output port")
							 (close-output-port file)
							 (set-my! 'file #f)))))


(use-parent-body <snapshot>)

;---- logfile methods

(model-method <logfile> (page-preamble self logger format)
				  (kdnl* '(introspection logfile) "[" (my 'name) ":"
							(class-name-of self) "]" "is preparing to dump")
				  (let ((filename (my 'filename))
						  (file (my 'file))
						  )
					 
					 (if (not (or (not filename) (string? filename)))
						  (error (string-append (my 'name) " has a filename which is "
														"neither false, nor a string.")))

					 ;; Open a new file
					 (if (not file)
						  (begin
							 (kdnl* '(introspection logfile) "[" (my 'name) ":"
									  (class-name-of self) "]" "is opening a log file")
							 (if (zero? (string-length filename))
								  (set! file (current-output-port))
								  (set! file (open-output-file filename)))
							 )

						  (set-my! 'file file)))
				  )

(model-method <logfile> (page-epilogue self logger format)
				  (kdnl* '(introspection logfile) "[" (my 'name) ":"
							(class-name-of self) "]" "has finished a dump")
				  #!void)


;---- log-map methods


;----- (initialize) 
(add-method initialize
				(make-method (list <log-map>)
								 (lambda (initialize-parent self args)
									;;(dnl "<thing> init")
									(initialize-parent) ;; call "parents" last
															  ;; to make the
															  ;; initialisation list
															  ;; work
									(initialise self '(type log-map format ps))
									(initialise self args)
									;; keep all files
									)))

(use-parent-body <log-map>)



(model-method <log-map> (page-preamble self logger format)
				  ;; This *must* replace it's parent from <snapshot> since
				  ;; it doesn't work with a traditional port
				  (kdnl* '(log-* log-map) (name self) "[" (my 'name) ":"
							(class-name-of self) "]" "in page-preamble")
				  (let ((filename (my 'filename))
						  (filetype (my 'filetype))
						  (file (my 'file))
						  (t (my 'subjective-time))
						  )

					 (cond
					  ((not (or (not filename) (string? filename)))
						(error (string-append (my 'name) " has a filename which is "
													 "neither false, nor a string.")))

					  ((not (or (not filetype) (string? filetype)))
						(error (string-append (my 'name) " has a filetype which is "
													 "neither false, nor a string.")))

					  ((not (number? t))
						(error (string-append (my 'name) " has a subjective time "
													 "which is not a number.")))
					  )

					 ;; Open a new file
					 (cond
					  ((not file)
						(kdnl* '(introspection log-map) "[" (my 'name) ":"
								 (class-name-of self) "]" "is preparing to dump")
						
						(let ((fn (introspection-filename (my 'filename)
																	 (my 'filetype) t)))
						  (set-my! 'lastfile (my 'currentfile))
						  (set-my! 'currentfile fn)
						  (if (zero? (string-length fn))
								(abort "Oh. Bother.")
								(set! file (make-ps fn '(Helvetica))))
						  ))
					  ((memq file (list (current-output-port) (current-error-port)))
						;; do nothing really
						(kdnl* '(introspection log-map) "[" (my 'name) ":"
								 (class-name-of self) "]" "has nothing to do")
						#!void
						)
					  (else 
						(kdnl* '(introspection log-map) "[" (my 'name) ":"
								 (class-name-of self) "]"
								 " Good, we've hit page-preamble with a file "
								 "that is still open.\nClosing the file (" 
								 (my 'lastfile) ") and opening a new one.")
						(close-output-port file)
						(set-my! 'file #f)
						(let ((fn (introspection-filename (my 'filename)
																	 (my 'filetype) t)))
						  (set-my! 'lastfile (my 'currentfile))
						  (set-my! 'currentfile fn)
						  (if (zero? (string-length fn))
								(abort "Oh. Bother.")
								(set! file (make-ps fn '(Helvetica))))
						  )
						)
					  )
					 (set-my! 'file file)))

(model-method <log-map> (page-epilogue self logger format)
				  ;; This *must* replace it's parent from <snapshot> since
				  ;; it doesn't work with a traditional port
				  (kdnl* '(log-* log-map) (name self) "[" (my 'name) ":"
							(class-name-of self) "]" "has page-epilogue")
				  (let ((file (my 'file))
						  (name (my 'currentfile)))
					 (if file
						  (begin
							 (file 'close)
							 (set-my! 'file #f)))
					 )
				  )


;; This logs to an open file
(model-method (<log-map> <procedure> <procedure> <symbol> <list>)
				  (log-data self logger format caller targets)
				  (lambda (target)	
					 (kdnl* '(log-* log-map) (name self) "[" (my 'name)
							  ":" (class-name-of self) "]" "in log-data"
							  (class-name-of target) (slot-ref target 'name))
					 (let* ((name (slot-ref target 'name))
							  (p (slot-ref self 'map-projection))
							  (ps (slot-ref self 'file))
							  )
						(ps 'comment "logging data for " name "****************")
						(ps 'moveto (list (p '(20 20))))
						(ps 'setgray 0.0)
						(ps 'Helvetica 14)
						(ps 'show (string-append (slot-ref self 'name)))
						(ps 'comment "finished logging data for " name)
						)))


;---- log-data methods
;----- (initialize) 
(add-method initialize
				(make-method (list <log-data>)
								 (lambda (initialize-parent self args)
									;;(dnl "<thing> init")
									(initialise self '(type log-data)) ;; keep all files
									(initialize-parent) ;; call "parents" last
															  ;; to make the
															  ;; initialisation list
															  ;; work
									(initialise self args)
									)))

(use-parent-body <log-data>)

(model-method <log-data> (agent-prep self start end kernel . args)
				  ;; This opens the output file on initialisation.
				  (agent-prep-parent) ;; parents should prep first
				  (kdnl* '(log-* log-data) (name self) "[" (my 'name) ":"
							(class-name-of self) "]" "in agent-prep")
				  
				  (let ((filename (my 'filename))
						  (filetype (my 'filetype)))
					 (if (string? (my 'filename))
						  (begin
							 (kdnl* '(log-* log-data) (name self) "[" (my 'name)
									  ":" (class-name-of self) "]" "opening "
									  (introspection-filename filename
																	  (if filetype filetype "")))
							 (set-my! 'file
										 (open-output-file
										  (introspection-filename filename
																		  (if filetype
																				filetype
																				""))))
							 (current-output-port))
						  (begin
							 (kdnl* '(log-* log-data) (name self) "[" (my 'name) ":"
									  (class-name-of self) "]"
									  "using stdout as the output file " )
							 (set-my! 'file (current-output-port))
							 )
						  )
					 )
				  (if (null? (my 'variables))
						(let ((vars (reverse
										 (unique*
										  (reverse
											(append
											 '(name subjective-time)
											 (apply append
													  (map extra-variable-list
															 (my 'introspection-list)))))))))
						  (slot-set! self 'variables vars)))
				  )


(model-method <log-data> (agent-shutdown self . args)
				  (kdnl* '(log-* log-data) (name self) "[" (my 'name) ":"
							(class-name-of self) "]" "in agent-shutdown")
				  (if (and (my 'file) (output-port? (my 'file))
							  (not (memq (my 'file)
											 (list (current-output-port)
													 (current-error-port)))))
						(begin
						  (close-output-port (my 'file))
						  (set-my! 'file #f) ;; leave it the way it should be left
						  ))
				  (agent-shutdown-parent) ;; Parents should shutdown last
				  )

(model-method <log-data> (page-preamble self logger format)
				  (page-preamble-parent) ;; opens the file

				  (if (not (output-port? (my 'file)))
						(abort "Serious problems getting an output port for "
								 (my 'name)))

				  (let ((il (my 'introspection-list))
						  (file (my 'file))
						  (show-field-name (my 'show-field-name))
						  (missing-val (my 'missing-val))
						  )
					 (case format
						((ps)
						 #f)
						(else
						 
						 
						 (if (not (member 'header (my 'preamble-state)))
							  (begin
								 (if (and (pair? il)
											 (null? (cdr il))) ;; agent name
																	 ;; comes first
													 ;; since it is
																	 ;; easy to prune
																	 ;; the first line
									  (begin
										 (display (string-append "# " (name (car il)))
													 (my 'file))
										 (newline file)))
							  
								 (let ((header 
										  (if missing-val
												(my 'variables)
												(let loop ((all-vars '())
															  (entities il))
												  (if (null? entities)
														(intersection
														 (uniq
														  (map
															string->symbol
															(sort (map symbol->string
																		  all-vars)
																	string<?)))
														 (my 'variables))
														(loop
														 (append
														  (map car
																 (class-slots
																  (class-of (car entities))))
														  (extra-variable-list (car entities))
														  all-vars) (cdr entities))))
												)
										  ))
									(display "# " file)
									(for-each
									 (lambda (x) (display " " file) (display x file))
									 header)
									(newline file))
								 (set-my! 'preamble-state
											 (cons 'header (my 'preamble-state)))
								 )
							  )
						 )
						)
					 )
				  )
						
;; This is typically never called since it "logs" the logfile.  Mostly
;; here as an example.
(model-method (<log-data> <procedure> <procedure> <symbol> <list> <boolean>)
				  (log-data self logger format caller targets . file)
				  (kdnl* '(log-* log-data) (name self) "[" (my 'name) ":"
							(class-name-of self) "]" "in log-data")
				  (let ((file (my 'file))
						  (show-field-name (my 'show-field-name))
						  (subjects (my 'introspection-list))
						  (targets (my 'variables))
						  )
					 (for-each (lambda (target) 
									 (display "**" file)
									 (for-each ;; field in the variable list
									  (lambda (field)
										 (if show-field-name
											  (begin
												 (display " " file)
												 (display field file)))

										 (cond
										  ((member field
													  (map car
															 (class-slots (class-of target))))
											(kdnl* '(log-* log-data logging-debug)
													 "     Dumping " field "="
													 (if (has-slot? self t)
														  (slot-ref self t)
														  "missing!"))
												 
											(display " " file)
											(display (slot-ref target field) file)
											)
										  ((member field (extra-variable-list target))
											(display " " file)
											(display (extra-variable target field) file)
											)
										  (missing-val
											(display " " file)
											(display missing-val file)))
										 )
									  (if #t targets
											(filter (not-member (my 'dont-log)) targets)))
									 (newline file)
									 )
								  subjects)
					 )
				  )


(model-method (<log-data>) (page-epilogue self logger format)
				  (kdnl* '(log-* log-data) (name self) "[" (my 'name) ":"
							(class-name-of self) "]" "in page-epilogue")
				  (if (and (pair? (my 'introspection-list))
							  (pair? (cdr (my 'introspection-list))))
						(or #t (newline (my 'file)))
						;; We don't want a blank line between each record!
						;; -- change #t to #f to get lines between "pages"
						)
				  )


;-  The End 


;;; Local Variables:
;;; mode: scheme
;;; outline-regexp: ";-+"
;;; comment-column:0
;;; comment-start: ";;; "
;;; comment-end:"" 
;;; End:
