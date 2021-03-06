; -*- mode: scheme; -*-
;-   Identification and Changes

;--

;	kernel.scm -- Written by Randall Gray 
;	Initial coding: 
;		Date: 2008.04.07
;		Location: localhost:/usr/home/gray/Study/playpen/kernel.scm.scm
;
"
    Copyright 2017 Randall Gray

    This file is part of Remodel.

    Remodel is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Remodel is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Remodel.  If not, see <http://www.gnu.org/licenses/>.
"

;-  Code 


;;(require 'sort)
;;(require 'pretty-print)
;;(require 'common-list-functions)

;;(load "stats-bins.scm")


;  
;  ***                                  *                      *     
;   *                                   *                      *     
;   *                                   *                      *     
;   *   * * **   * ***    ****   * **  ****    ****   * ***   ****   
;   *   ** *  *  **   *  *    *   *     *          *  **   *   *     
;   *   *  *  *  *    *  *    *   *     *      *****  *    *   *     
;   *   *  *  *  **   *  *    *   *     *     *    *  *    *   *     
;   *   *  *  *  * ***   *    *   *     *  *  *   **  *    *   *  *  
;  ***  *  *  *  *        ****    *      **    *** *  *    *    **   
;                *                                                   
;                *        

;;*** The kernel must be loaded *after* the agents are all created --
;;this is so it has access to the "run" "migrate" ... generic
;;methods.


;;---------------------------------------------------
;; Important routines which I Really Ought to Know ;;
;;---------------------------------------------------


;; (queue t stop runqueue . N)
;; t is model time, stop is when the whole model ought to stop 
;; runqueue is a list of run-records

;; (q-insert Q rec reccmp) inserts the record "rec" into the queue "Q"
;; sorting records with "reccmp"
;;; Call: (set! rq (q-insert rq (make-agent <whatever> ...) Qcmp))

(include "remodel-framework")

(definition-comment 'lookit-running-names
  "This is a flag used when debugging; if true the name of the running agent is"
  "printed when it starts to run.")

(define lookit-running-names #f) ;; emits the name of the running
;; agent if true

(define monitors-monitor-themselves #t) ;; If false, monitors will ignore any other monitor

;(load "postscript.scm")
;;; This is loaded here since it may be used to produce all sorts of
;;; snapshot data spanning agents

;; These variables are used by the postscript.scm code
(define developing #t)
(define current-page #f)
(define current-page-number 0)

;(define enabled-modify-queue-with #t); ;; This is potentially very dangerous to code/model stability

;#############################################################
(define Q '())  ;; This is the queue which holds the agents
					 ;; at the start of the simulation
;#############################################################

(define global-time 0)

(define Mortuary '());; We collect terminated agent here.  Termination *ought* to call shutdown!
(define Cemetary '());; We collect dead agents here when they are terminated.  Termination *ought* to call shutdown!


(define clock-started #f)

(define unit-alist (list (cons "s"  1)
								 (cons "min" min) (cons "mins" min)
								 (cons "hour" hour) (cons "hours" hours)
								 (cons "week" week) (cons "weeks" weeks)
								 (cons "year" year) (cons "years" years)
								 ))

(define display-units "days")
(define display-unit-value days)

(define (set-kernel-display-units str)
  (let ((a (assoc str unit-alist)))
	 (if a
		  (begin
			 (set! display-units (car a))
			 (set! display-unit-value (cadr a)))
		  (abort "Bad kernel display unit"))))


(define ACQ '()) ;; queue of things to insert before the next agent runs

(define (terminating-condition-test . args)
  #f)

(define valid-agent-states '(ready-for-prep active dead terminated ))
(define valid-queue-states '(ready-for-prep ready-to-run running suspended terminated ))

;; ready-for-prep means that the agent has been created, but has not been inserted into the runqueue
;; ready-to-run means that the agent is active and may be run by the scheduler
;; running means that the agent is currently running (this is pertinent for inter-agent communication and parallelisation)
;; dead means the agent should still be kept in the system and may be interacted with, but that it
;;     runs an alternate "dead-agent" code path in its model body --- typically associated with decay
;;     Trees, for example, may have a trivial dead-agent code path if they are unlikely to rot
;; suspended agents consume time and update their subjective time, but do nothing else (not even a dead-agent
;;     path)
;; terminated agents take no further part in the simulation and should be removed from the runqueue.


(define keep-terminated-agents #t) ;; shunt them into a list of terminated agents so they are available for
                                         ;; post-run analysis 
(define terminated-agents '())

;---------------------------------------------------
;               Kernel support
;---------------------------------------------------

(define (examine-queue Q)
  (for-each
	(lambda (n x)
	  (dnl* n (class-name (class-of x)) (taxon x) (subjective-time x) (agent-state x)))
	  (seq (length Q)) Q))


;; remove an object from a list
(define (excise obj lst)
  (letrec ((head (list '*head*)))
	 (letrec ((inner-remove
				  (lambda (lst tail)
					 (cond ((null? lst)
							  lst)
							 ((not (pair? lst))
							  #f)
							 ((eqv? obj (car lst)) (inner-remove (cdr lst) tail))
							 (#t
							  (set-cdr! tail (list (car lst)))
							  (inner-remove (cdr lst) (cdr tail)))))))
		(inner-remove lst head))
	 (cdr head)))

(definition-comment 'Qcmp "Compares the subjective time of two agents -- this is a < style comparison")
(define (Qcmp r1 r2) ;; reducing the amount of time this takes will have a performance impact
  ;;(start-timer 'Qcmp)
  ;;(let ((result
  (cond
	((and (number? r1) (number? r2))
	 (<= r1 r2))
	((and (number? r1) (not (number? r2)))
	 #t)
	((and (not (number? r1)) (number? r2))
	 #f)

	((and (symbol? r1) (symbol? r2))
	 (string<=? (symbol->string r1) (symbol->string r2)))
	((and (symbol? r1) (not (symbol? r2)))
	 #t)
	((and (not (symbol? r1)) (symbol? r2))
	 #f)

	((and (isa? r1 <agent>)
			(isa? r2 <agent>))
			(let ((st1 (subjective-time r1))
					(st2 (subjective-time r2)))
			  (cond
				((> st1 st2) #f)
				((<= st1 st2) #t)
				(#t (let ((p1 (priority r1))
							 (p2 (priority r2)))
						(cond
						 ((<= p1 p2) #f)
						 ((> p1 p2) #t)
						 (#t (<= (jiggle r1)(jiggle r2)))
						 )
						)))
			  ))
	))
;)
;;(stop-timer 'Qcmp)
	 ;;result)
;  )



(definition-comment 'map-q "applies a query function (like 'subjective-time') to members of a runqueue, q")
(define (map-q arg q)
  (map (lambda (s) (arg s)) q))


(definition-comment 'q-filter
  "uses 'filter' and the passed in predicate to return a subset" "of the list of agents, rq")
(define (q-filter qf-rq predicate)
  (filter (lambda (process) (predicate process)) qf-rq))

(definition-comment 'running-queue
  "This returns a boolean which indicates if 'rq' is a valid runqueue" "which has not finished running")
(define (running-queue rq-rq stop)
  (cond
	((null? rq-rq) #f)
	((not (pair? rq-rq)) #f)
	((not (list? rq-rq)) #f)
	((not (agent? (car rq-rq))) #f)
	(#t (let ((f (car rq-rq)))
			(< (slot-ref f 'subjective-time) stop)))))

(definition-comment 'model-time "returns the current 'now'  of the agent at the head of the queue (unused)")
(define (model-time mt-rq stop)
  (if (running-queue mt-rq stop)
		(if (or (null? mt-rq) (not (list? mt-rq)))
			 mt-rq
			 (let ((f (car mt-rq)))
				(slot-ref f 'subjective-time))
			 )
		'end-of-run
		)
  )

(definition-comment 'interval
  "returns an interval (tick-length) based on the current time, the"
  "desired tick length, the nominated end of the run and a list of"
  "target times")

(define (interval t ddt stopat tlist)
  ;; tlist is a sorted queue of times to run
  (kdebug 'kernel-scaffolding "Called interval, T =" (/ t display-unit-value) ", ddt =" ddt ", stops at" stopat ", tlist:" tlist)
  (if (< (- stopat t) ddt)
		(set! ddt (- stopat t)))

  ;; This could (and should) be a lot simpler.

  (cond
	((or (not tlist) (null? tlist)) ;; treat a false tlist as equivalent to '()
	 (kdebug 'kernel-scaffolding "no tlist")
	 ddt)
	((and (list? tlist) 
			(number? (car tlist))
			(= (car tlist) t)
			)
	 (kdebug 'kernel-scaffolding "t == (car tlist)")
	 (if (pair? (cdr tlist)) ;; if there is a ttr in the tlist which is closer than t+ddt...
		  (let ((p (- (cadr tlist) t)))
			 (< p ddt)
			 (kdebug 'kernel-scaffolding "(cadr tlist) < t+ddt")
			 (set! ddt p)))
	 ddt)
	((and (list? tlist) 
			(number? (car tlist))
			)
	 (let ((dt (- (car tlist) t)))
		(if (< dt ddt)
			 dt
			 ddt)))
	(else 'bad-time-to-run)))



(definition-comment 'insert@ "Returns the index AT which to insert")
(define (insert@ lst ob cmp) 
  (cond
	((null? lst) 0)
	((null? (cdr lst)) 1)	 ;; Singleton.
	(#t
	 (let insert-loop  ((m 0) (M (- (length lst) 1)))
		;;(kdebug 'queue-insertion (name ob)"at time" (slot-ref ob 'subjective-time) ": m =" m "M =" M)

		(let* ((m! (list-ref lst m))
				 (M! (list-ref lst M))
				 (H (truncate (/ (+ m M) 2)))
				 (H! (list-ref lst H))
				 (o<m (cmp ob m!))
				 (m<o (cmp m! ob))
				 (o<M (cmp ob M!))
				 (M<o (cmp M! ob))
				 (H<o (cmp H! ob))
				 (o<H (cmp ob H!))
				 )
		  (cond
			((= m M) m) ;; Must be so
			((and (= (+ m 1) M) o<M) M)
			(o<m m) ;; off the edge
			(M<o (+ 1 M)) ;; off the other edge
			((not (or o<m m<o)) m) ;; must be equal
			((not (or o<H H<o)) H) ;; must be equal
			((not (or o<M M<o)) M) ;; must be equal
			(o<H (insert-loop m H))
			(H<o (insert-loop H M))
			(#t (abort 'impossible-insert@-failure))))))
	)
  )

(definition-comment 'q-insert
  "inserts a run record in the right place in the queue Q")
(define kernel-time 0)


;; Do *not* try an use the timer code (define% ...) on this, it will eat your happiness.
(define (QI Q rec reccmp)
  (let loop ((ptr Q))
	 (cond
	  ((null? ptr) (list rec))
	  ((reccmp rec (car ptr))
		(cons rec ptr))
	  (else (cons (car ptr) (loop (cdr ptr)))))))

;; This returns the queue, and it must be called using the global variable Q like so: (set! Q (q-insert Q ...))
;;(define (broken-Q-Insert Q rec reccmp)
;;  (if (memq (slot-ref rec 'agent-state) '(ready-to-run running suspended))
;;		(begin
;;		  (start-timer 'q-insert)
;;		  (let ((result 
;;					(cond
;;					 ((not (isa? rec <agent>)) (error "Passed a non-agent to q-insert" rec))
;;					 ((eq? (slot-ref rec 'agent-state) 'terminated)
;;					  (hoodoo rec "q-insert 1")
;;					  Q)
;;					 (#t
;;					  (let ((j (slot-ref rec 'jiggle))
;;							  )
;;						 (if (pair? Q) (set! Q (excise rec Q)))
;;						 
;;						 (if (or (eq? j #t) (number? j))
;;							  (if (or (boolean? j) (and (positive? j) (< j 1.0)))
;;									(set-jiggle! rec (abs (random-real)))
;;									)
;;							  (begin
;;								 (set-jiggle! rec 0))) ;; Coerce non-numerics to zero
;;						 
;;						 (stop-timer 'q-insert)
;;						 (let ((ix (insert@ Q rec reccmp)))
;;							(start-timer 'q-insert)
;;							(if (number? ix)
;;								 (append (list-head Q ix) (cons rec (list-tail Q ix)))
;;								 (error "bad return from insert@" ix))))
;;					  )
;;					 ))
;;				  )
;;			 (stop-timer 'q-insert)
;;			 result))
;;		(if (eq? (slot-ref rec 'agent-state) 'terminated)
;;			 (begin
;;				(hoodoo rec "q-insert 2")
;;				Q)
;;			 (append Q (list rec))) ;; we stick them at the end of the list to keep them in the system
;;		))

(define q-insert QI)

;;; (define (q-mis-insert Q rec reccmp) ***
;;;   (error "This is probably buggered") ***
;;;   (if (eq? (slot-ref rec 'agent-state) 'ready-for-prep) ***
;;; 		(cons rec Q) ***
;;; 		(let ((lQ (length Q))) ***
;;; 		  (if (isa? rec <agent>) ***
;;; 				(let ((j (slot-ref rec 'jiggle)) ***
;;; 						(call-starts (cpu-time)) ***
;;; 						) ***
;;; 				  (if (pair? Q) (set! Q (excise rec Q))) ***

;;; 				  (if (or (eq? j #t) (number? j)) ***
;;; 						(if (or (boolean? j) (and (positive? j) (< j 1.0))) ***
;;; 							 (set-jiggle! rec (abs (random-real))) ***
;;; 							 ) ***
;;; 						(begin ***
;;; 						  (set-jiggle! rec 0))) ;; Coerce non-numerics to zero ***
;;; 				  (if (or (< lQ 2) (sorted? Q reccmp)) ***
;;; 						(let ((ix (insert@ Q rec reccmp))) ***
;;; 						  (set! kernel-time (+ kernel-time (- (cpu-time) call-starts))) ***
;;; 						  (if (> ix lQ) ***
;;; 								(append Q (list rec)) ***
;;; 								(append (list-head Q ix) (list rec) (list-tail Q ix))) ***
;;; 						  ) ***
;;; 						(begin ***
;;; 						  (let* ((f (append Q (list rec))) ***
;;; 									(sf (sort f reccmp)) ***
;;; 									) ***
;;; 							 (set! kernel-time (+ kernel-time (- (cpu-time) call-starts))) ***
;;; 							 sf)) ***
;;; 						) ***
;;; 				  ) ***
;;; 				(begin ***
;;; 				  (dnl* "The item:" rec "was passed to be inserted into the runqueue.  Dropping it.") ***
;;; 				  (kdebug 'error "The item:" rec "was passed to be inserted into the runqueue.  Dropping it.") ***
;;; 				  Q) ***
;;; 				))) ***
;;;   ) ***



;---------------------------------------------------
;           Kernel -- the main loop
;---------------------------------------------------

(definition-comment 'test-queue-size
  "this is so we catch runaway growth")
(define (test-queue-size tqs-rq N)
  (if (and (number? N) (> (length tqs-rq) N))
		(begin
		  (dnl "There are " (length tqs-rq)
				 " entries in the runqueue when we expect at most " N);
;;		  (dnl "These entities total "
;;				 (apply + (map (lambda (x) (members x)) tqs-9q)) " members");
		  
;;		  (for-each (lambda (me) 
;;					(dnl " " (representation me) ":" (name me) " (" me ")	@ "
;;						  (slot-ref me 'subjective-time) " with " (members me))) tqs-rq)
		  (abort "Failed queue size test")
		  ))
  )


(define (hoodoo agent proc)
  (case (agent-state)
	 ('terminated (set! terminated-agents (cons agent terminated-agents)))
	 (else (dnl* "Bad hoodoo workin in" proc) (error "Impossible codepath" agent proc))))


(definition-comment 'queue
  "This is the main loop which runs agents and reinserts them after"
  "they've executed. Typically one would begin the simulation by "
  "calling (queue start stop run-queue)."
  ""
  "(queue) dispatches control to an agent by a call to (run-agent ...)"
  ""
  "There is extra support for inter-agent communication and migration."
  "The queue doesn't (and *shouldn't*) care at all about how much"
  "time the agents used."
  )


(define tracing-q 'not-yet-run) ;; State of the queue

;; This typically runs the agent at the head of the queue
(define (queue t stop runqueue #!rest N)
  (set! Q runqueue)

  (if (not clock-started)
		(set! clock-started (real-time)))
  (set! global-time t)
  
  (set! tracing-q (sort runqueue Qcmp))
  
  (if (eq? indicate-progress #t) (set! indicate-progress -1))
  (set! N (if (null? N) #f (car N)))

;;  (start-timer 'queue)
  (let loop ((q-rq runqueue)
				 )
	 (if (pair? ACQ)
		  (begin
			 (set! q-rq (sort (append q-rq ACQ) Qcmp))
			 (set! runqueue q-rq)
			 (set! ACQ '())
			 ))
	 (if (and indicate-progress (number? indicate-progress) (> t indicate-progress))
		  (begin
			 (set! indicate-progress t)
			 (display "t = ")
			 (if #t
				  (display (scaled-time (subjective-time (car q-rq))))
				  (begin
					 (display (/ (subjective-time (car q-rq)) display-unit-value))
					 (display " ")
					 (display display-units)
					 ))

;			 (if #f
;				  (display (scaled-time-ratio (+ 1 (subjective-time (car q-rq))) (+ 1 (- (real-time) clock-started))))
;				  (begin
;					 (display (/(+ 1 (subjective-time (car q-rq))) (+ 1 (- (real-time) clock-started))))
;					 (display "s/s ")))
			(display (string-append " -- "(number->string (round (* 100 (/ (subjective-time (car q-rq)) end)))) "%"))
			(if display-Q-length (display (string-append " " (number->string (length q-rq)) " agents")))
			(newline)
			)
		  )
	 
	 (set! Q
	  (cond
	  ((terminating-condition-test q-rq)
		(set! runqueue q-rq)
		(list 'terminated q-rq)
		)
	  ((null? q-rq)
		'empty-queue)
	  ((and (list? q-rq) (symbol? (car q-rq)))
		(dnl* "Q symbol:" (car q-rq) "============================================")
		q-rq)
	  ((file-exists? "halt")
;;		(stop-timer 'queue)
		(delete-file "halt")
		(shutdown-agents q-rq)
		q-rq)
	  ((and (< t stop) (running-queue q-rq stop))
		(set! t (apply min (map-q subjective-time q-rq)))
		;;(test-queue-size q-rq N)
		(if (eq? (slot-ref (car q-rq) 'agent-state) 'terminated) ;; this is Just In Case
			 (begin
				(hoodoo (car q-rq) "queue")
				(set! runqueue q-rq)
				(loop (cdr q-rq)))
			 (begin
;;				(stop-timer 'queue)
				(set! q-rq (run-agent t stop q-rq))
;;				(start-timer 'queue)
				(test-queue-size q-rq N)
				(set! runqueue q-rq)
				(loop q-rq)))
		)
	  ((and (>= t stop) (running-queue q-rq stop))
		(stop=timer 'queue)
		(set! runqueue q-rq)
		(shutdown-agents q-rq))
	  )
	 )
;;  (stop-timer 'queue)
  (set! Q runqueue)
  )
  Q)


(definition-comment 'convert-params "converts the parameter vector 'params' to reflect a new representation")
(define (convert-params params rep)
  (let* ((newparams params)
			)
	 (list-set! newparams 3 rep)
	 (list-set! newparams 5 (if (eqv? rep 'individual) 1 0))
	 newparams
	 ))


(definition-comment 'distances-to "Returns the nominal distance between agents of a given type and a location")
(define (distances-to what agentlist loc)
  (map (lambda (agent) 
			(if (and (procedure? agent)
						(eqv? (representation agent) what))
				 (distance loc (location agent))
				 2e308)
			)
		 agentlist)
  )


(definition-comment 'distances-to-agents "Returns a list of nominal distance between a location and a members of a set of agents")
(define (distances-to-agents agentlist loc)
  (map (lambda (agent) 
			(if (procedure? agent)
				 (distance loc (location agent))
				 1e308)
			)
		 agentlist)
  )

(definition-comment 'distances-to "Returns the nominal distance between <population>s and a location")
(define (distances-to-populations agentlist loc)
  (distances-to 'population agentlist loc))


(definition-comment 'min-index "returns the index of the left-most (on the number line) value in n-list")
(define (min-index number-list)
  (let ((n (and (list? number-list) (pair? number-list) (apply andf (map number? number-list)) (apply min number-list))))
	 (let loop ((i 0)
					 (nl number-list))
		(cond
		 ((= (car nl) n) i)
		 ((null? nl) (error "bad result"))
		 (#t (loop (+ 1 i) (cdr n)))))))


;; Dunno *what* I was thinking :-)
;;; (define (Min-index n-list)
;;;   (cond 
;;; 	((not (list? n-list)) 'not-a-list)
;;; 	((null? n-list) #f)
;;; 	((not (apply andf (map number? n-list)))
;;; 	 'Non-number-entry)
;;; 	(#t
;;; 	 (let* ((k (length n-list))
;;; 			  (result (let loop ((ix 0)
;;; 										(best #f)
;;; 										)
;;; 							(if (>= ix k)
;;; 								 best
;;; 								 (let ((n (list-ref n-list ix)))
									
;;; 									(cond 
;;; 									 ((infinite? n) ;; skip invalid entries
;;; 									  (loop (1+ ix) best))
;;; 									 ((and (number? n)
;;; 											 (or 
;;; 											  (not best)
;;; 											  (let ((b (list-ref n-list best)))
;;; 												 (or (infinite? b)
;;; 													  (and (number? best) (<= n b)))))
;;; 											 )
;;; 									  (loop (1+ ix) ix))
;;; 									 (#t (loop (1+ ix) best)))
;;; 									))) ))
;;; 		(if (or (not result) (infinite? result) (>= result 1e308))
;;; 			 #f
;;; 			 result)
;;; 		))
;;; 	)
;;;   )



(define (agent-kcall me #!rest args)
  (if (null? args)
		(error "No query made to kernel through" me)
		(apply (slot-ref me 'kernel) args)))



(definition-comment 'kernel-call
  "This is the call into the kernel, agents can query for agent lists, agent count, times....
If the tag is a string it is silently converted to a symbol, *and* the argument is 
to the query is *NOT* unwrapped --- if args end up of the form ((....)), it stays that way!

Agents have a wrapper for this function--- kernel --- which makes calls simpler.  Using this 
wrapper from the repl might look like

> ((slot-ref (car Q) 'kernel) 'check)

though in the agent's code it would look like
        (kernel 'check)
)

since the function saved in the kernel slot captures the agent's closure.  More often it
will be invoked within an agents model-body like
   ...
	(for-each forage-if-coincident (kernel 'providers? 'vegetation))
   ...
or something like that.


NOTE PARTICULARLY: if the flag restricted-kernel-access is set, agents can only access the kernel while 
their model-body is running.  
")

;; This is wrapped by "kernel" in the agents .... recall that objects do not have
;; access to the kernel except by using kernel-call.


"
There are two issues associated with the 'locate' family and agents with multiple 
loci: as the client, the locates ought to query each of its locations (they should
be obtained by a call---(location client)--- and then individually called merged and made unique.

As a target, each of their locations should be tested against the
location of the client, and any that match will be proxified.
"


(define (kernel-call client Q call-op #!rest args)
  (if (null? args) (set! args #f))
  
  ;(dnl* "In kernel-call, Q:" (name client) call-op args)
  ;;(dnl* (map name Q))

  (if (string? call-op)
		(set! call-op (string->symbol call-op))
		(if (and (pair? args) (null? (cdr args)) (pair? (car args)) (= 1 (length args)))
			 (set! args (car args))) ;;
		)

  (cond
   ((and (or (eqv? client <kernel>) (isa? client <kernel>) (isa? client <monitor>)) (procedure? call-op))
	 (if monitors-monitor-themselves
		  (filter call-op Q) ;; *can* return itself ... monitors can monitor monitors
		  ))
	
	;; The format expected is (kernel /target-agent/ /target-agent-class/  /method/ args....)
	((and args (pair? args) (isa?  call-op (car args)))
	 (apply (cadr args) (cons call-op (cddr call-op))))

   ((symbol? call-op)
	 ;;(dnl* "Dispatch to standard call-op:" call-op)
    (case call-op
		('runqueue
		 (if (or (eqv? client <kernel>) (isa? client <kernel>) (isa? client <monitor>) (isa? client <introspection>))
			  Q
			  #f))
		('time (model-time Q +inf.0)) ;; current time in the model (the subjective-time of the head of the queue)
		
		('acquire ;; expects a list of agents to introduce into an agent's subsidiary list
		 ;; (kernel-call Q caller 'acquire host-agent active? agent-list)
		 (let ((okQ (filter (lambda (x) (isa? x <agent>)) (caddr args))))
			(apply acquire-agents args)
			))

		;; ('check
		;;  (list client 'mate))

		;; ('check!
		;;  (list client 'mate!))
		
		
		;; ('find-agent
		;;  (let ((type (car args))) 
		;; 	(filter (lambda (x)
		;; 				 (let ((xtype (slot-ref x 'type)))
		;; 					(or (eqv? xtype type)
		;; 						 (and (string? type)
		;; 								(string? xtype)
		;; 								(string=? type xtype))
		;; 						 (and (procedure? type)
		;; 								(type x)) 
		;; 						 )))
		;; 			  Q)))
		('locate* ;; This ignores temporal consistency
;(dnl* "locate*" (name client) "|" call-op "|" args)
		 (if (null? args) (list-copy Q)
			  (let* ((selector (car args))
						(polygon (cond
									 ((and (null? (cdr args)) (has-slot? client 'hull)) (slot-ref client 'hull)) ;; only <array> classes have hull
									 ((and (pair? (cdr args)) (polygon%? (cadr args)))
										 (cadr args))
									 (else #f)))
						(radius (if (and (not polygon) (pair? (cdr args)) (number? (cadr args)))  (cadr args) #f))
						(location (if (and radius (not polygon) (not (null? (cddr args)))) (caddr args) (if (has-slot? client 'location) (slot-ref client 'location) #f)))
						)
				 (let ((pl (cond
							  (location (locate client Q selector radius location))
							  (polygon (locate client Q selector polygon))
							  (else (locate client Q selector))))) 
;					(dnl* "...Found" pl)
					(if (void? pl) (bugger))
;					(dnl* "about to proxy" pl)
					(if use-proxies
						 (cond
						  (location (proxify pl Q radius location))
						  (polygon (proxify  pl Q polygon))
						  (else (proxify  pl Q)))
						 pl)

				 ))))

		('locate ;; this enforces temporal consistency of a sort: Select things that are "current"
;		 (dnl* "locate" (name client) "|" call-op "|" args)
		 (let* ((selector (car args))
				  (polygon (cond
								((and (null? (cdr args)) (has-slot? client 'hull)) (slot-ref client 'hull)) ;; only <array> classes have hull
								((and (pair? (cdr args)) (polygon%? (cadr args)))
								 (cadr args))
								(else #f)))
				  (radius (if (and (not polygon) (pair? (cdr args)) (number? (cadr args)))  (cadr args) #f))
				  (location (if (and radius (not polygon) (not (null? (cddr args)))) (caddr args) (if (has-slot? client 'location) (slot-ref client 'location) #f)))
				  )
;			(dnl* 'LOCATE selector radius location)
			;;;(dnl* "(locate ...)" (pp-to-string selector) location radius)
			(let* ((b (subjective-time client))
					 (d (+ b (slot-ref client 'dt)))
					 (pl (filter (lambda (x)
								  (let ((st (subjective-time x)))
									 (and (<= b st) (<= st d))))
								(cond
								 (location (locate client Q selector radius location))
								 (polygon (locate client Q selector polygon))
								 (else (locate client Q selector)))
								))
					 )
			  (if (void? pl) (bugger))
			  (if use-proxies
					(cond
					 (location (proxify pl Q radius location))
					 (polygon (proxify  pl Q polygon))
					 (else (proxify  pl Q)))
					pl)
			  )
			))


		 ('locate<=t ;; this enforces temporal consistency of a sort: Select things that are behind me
		 (let* ((selector (car args))
				  (polygon (cond
								((and (null? (cdr args)) (has-slot? client 'hull)) (slot-ref client 'hull)) ;; only <array> classes have hull
								((and (pair? (cdr args)) (polygon%? (cadr args)))
								 (cadr args))
								(else #f)))
				  (radius (if (and (not polygon) (pair? (cdr args)) (number? (cadr args)))  (cadr args) #f))
				  (location (if (and radius (not polygon) (not (null? (cddr args)))) (caddr args) (if (has-slot? client 'location) (slot-ref client 'location) #f)))
				  )
			;;;(dnl* "(locate ...)" (pp-to-string selector) location radius)
			 (let* ((b (subjective-time client))
					  (d (+ b (slot-ref client 'dt)))
					  (pl (filter (lambda (x)
										  (let ((st (subjective-time x)))
											 (<= st b) ))
									  (cond
										(location (locate client Q selector radius location))
										(polygon (locate client Q selector polygon))
										(else (locate client Q selector)))
									  ))
					  )
				(if (void? pl) (bugger))
				(if use-proxies
					 (cond
					  (location (proxify pl Q radius location))
					  (polygon (proxify  pl Q polygon))
					  (else (proxify  pl Q)))
					 pl)
				)
			 ))

		 ('locate>=t ;; this enforces temporal consistency of a sort: Select things that are ahead of me
		 (let* ((selector (car args))
				  (polygon (cond
								((and (null? (cdr args)) (has-slot? client 'hull)) (slot-ref client 'hull)) ;; only <array> classes have hull
								((and (pair? (cdr args)) (polygon%? (cadr args)))
								 (cadr args))
								(else #f)))
				  (radius (if (and (not polygon) (pair? (cdr args)) (number? (cadr args)))  (cadr args) #f))
				  (location (if (and radius (not polygon) (not (null? (cddr args)))) (caddr args) (if (has-slot? client 'location) (slot-ref client 'location) #f)))
				  )
			;;;(dnl* "(locate< ...)" (pp-to-string selector) location radius)
			 (let* ((b (subjective-time client))
					  (d (+ b (slot-ref client 'dt)))
					  (pl (filter (lambda (x)
										  (let ((st (subjective-time x)))
											 (>= st b) ))
									  (cond
										(location (locate client Q selector radius location))
										(polygon (locate client Q selector polygon))
										(else (locate client Q selector)))
									  ))
					  )
				(if (void? pl) (bugger))
				(if use-proxies
					 (cond
					  (location (proxify pl Q radius location))
					  (polygon (proxify  pl Q polygon))
					  (else (proxify  pl Q)))
					 pl)
				)
			 ))


		('shutdown
		 (let ((A (if (pair? args) args (list args))))
			(shutdown-agents A) ;; WAS HAVING ISSUES WITH A SINGLE AGENT BEING PASSED
			(for-each (lambda (a) (set! Q (excise a Q))) A)
			))

		('remove' ;; expects a list of agents to be removed from the runqueue
		 (let ((A (if (pair? args) args (list args))))
			(for-each (lambda (a)
							(agent-shutdown a)
							(set! Mortuary (cons a Mortuary))
							(set! Q (excise a Q))
							) A)
			))

		('containing-agents ;; returns a list of agents which report as containing any of the list of arguments
		 (error "i-contain is not implemented")
		 (filter (lambda (x) (i-contain x args)) Q))

		('providers? ;; returns a list of agents which provide indicated things
		 (cond
		  ((and (pair? args) (pair? (car args)) (null? (cdr args))) (filter (lambda (x) (provides? x (car args))) Q))
		  ((and (pair? args) (pair? (car args)) (not (null? (cdr args))))
			(error "bad options passed in kernel call to providers?" args))
		  (#t (filter (lambda (x) (provides? x args)) Q)))
		 )	

		('agent-count (length Q))
		('next-agent
		 (if (or (eqv? client <kernel>) (isa? client <kernel>) (isa? client <monitor>))
			  (if (null? Q) Q (car Q))
			  #f))
		('min-time
		 (if (null? Q) 0 (apply min (map subjective-time Q))))
		('max-time
		 (if (null? Q) 0 (apply max (map subjective-time Q))))
		('mean-time
		 (if (null? Q)
			  0
			  (/ (apply + (map subjective-time Q)) (length Q))))


		;;**********************************************************************************************************************
		;; Accessing values through the following mechanism may make distributed and concurrent processing more straightforward.
		;;**********************************************************************************************************************

		('resource-value ;; returns the value of a resource from a nominated agent -- (kernel 'resource-value other 'seeds)
		 (if (apply provides? args)
			  (apply value args)
			  #f))

		('set-resource-value! ;; sets the value of a resource from a nominated agent
		 (if (apply provides? args)
			  (or (apply set-value! args) #t)
			  #f))

		('add-resource-value! ;; adds to the value of a resource from a nominated agent
		 (if (apply provides? args)
			  (or (apply add! args) #t)
			  #f))

		(else (error "Unrecognised kernel-call request" call-op args)))
	 )
   (#t (error 'kernel-call:bad-argument))
   ))
  
	




;; The agent function, "process",  must respond to the following things
;;    (snapshot agent)

;;    (i-am agent)
;;    (is-a agent)
;;    (representation agent)
;;    (name agent)
;;    (dt agent)
;;    (parameters agent)

;;    (run-at agent t2)
;;    (run agent currenttime stoptime kernel)



;; The return values from agents fall into the following categories:

;; 	a symbol
;; 		is automatically inserted at the head of the queue and
;; 		execution is terminated (for debugging)

;; 	'ok
;; 		normal execution

;; 	(list 'introduce-new-agents dt list-of-new-agents)
;; 	   indicates that the agents in list-of-new-agents should be
;; 	   added to the simulation

;; 	(list 'remove)
;; 	   indicates that an agent should be removed from the simulation

;; 	(list 'migrate list-of-suggestions)
;; 	   the list-of-suggestions is so that an external assessment routine 

;; 	(list 'domain message-concering-domain-problem)
;; 		usually something like requests for greater resolution...

;; 	(list 'migrate)
;;      indicates that a model has changed its representation for some reason


(definition-comment 'prep-agents
  "prepares agents in Q for running, particularly at the start of a simulation"
  "Both prep-agents and shutdown-agents make use of 'kernel-call' whose"
  "arguments are the runqueue, the agent making the request, and any"
  "arguments that might be required."
  )	

(define (prep-activate pa-rq q-entry)
  (kdebug 'prep "Prepping, in lambda")
  (if (isa? q-entry <agent>)
		(let ((kernel (lambda x (apply kernel-call (cons q-entry (cons pq-rq x )))))
				)
		  (if (not (eq? (slot-ref q-entry 'agent-state) 'ready-for-prep))
				(dnl* (cnc q-entry) (name q-entry) "is being prepped, but has a state of" (slot-ref q-entry 'agent-state)))
		  (kdebug 'prep "Prepping in apply" (name q-entry))
		  (slot-set! q-entry 'agent-state 'active)
		  (initialise-instance q-entry)
		  (slot-set! q-entry 'queue-state 'ready-to-run)
		  ;;(agent-prep q-entry start end)
		  )
		(and (kdebug 'complaint q-entry "is not an agent: cannot prep") #f)
		)
  )

(define (prep-agents Q start end)
  (if (isa? Q <agent>)
		(agent-prep Q start end)
		(begin
		  (kdebug 'prep "Prepping from" start "to" end "    with" Q)
		  (set! Q (sort Q Qcmp))
		  (kdebug 'prep "sorted queue")

		  ;;  (dnl* "Prepping from" start "to" end)
		  ;;(pp (map (lambda (x) (cons (name x) (slot-ref x 'agent-state))) Q))
		  
		  (for-each (lambda (x)
						  (prep-activate Q x)) Q)
		  )
		))

(definition-comment 'shutdown-agents "Tells each agent in Q to shutdown")
(define (shutdown-agents Q . args)
  (for-each
	(lambda (A)
	  (let* ((kernel (lambda x (apply kernel-call (cons A (cons Q x)))))
				)
		 (apply agent-shutdown (cons A (cons kernel args)))
		 )
	  )
	Q)
  )

(define location-tree  '())
(define split-at 16) ;; bisects cell when there are 16 entities or more
(define split-flexibly #f) ;; Not implemented yet -- will allow each subdivision to be unequal in area
(define use-queue-for-locate #t)


" This is a somewhat complicated routine; it handles the bulk of the
business of agents finding each other to interact with (usually to
interrogate, eat, flee-from or mate-with).

	 Its arguments can be 
      nil                    -- return all the agents (without list-copy)
		#t                     -- return all agents (with list-copy)
		#f                     -- return the empty list
      a class                -- return agents of the class
      a symbol               -- return agents which provide the symbol
      a string               -- return agents with that taxon
      a procedure            -- return agents for which the procedure is true
      a list                 -- return agents which match any of the selectors *has-slot?
											*provides? *is-taxon? *is-taxon-ci? 
                                 *is-taxon-wild? *is-taxon-wild-ci?
                                 *has-slot? *has-data? *is-class? 
										  Exactly which is used is determined by the first (otherwise 
                                ignored) symbol --- such as 'is-taxon-ci? --- in the list

                                
		#t number locus        -- return all agents which are within radius or have no location
		#f number locus        -- return only locus agents which are within the radius
      class number locus     -- return agents of the class which are within the radius
      symbol number locus    -- return agents that provide the service and are close
      string number locus    -- return agents with that taxon and are close
      procedure number locus -- return agents for which the procedure is true and are close
      list number locus      -- return agents which match any of the elements and are close
                                as above

   Ignoring class/symbol/taxon issues we have the following filtering

	none
	single point (arg) versus single point (agent) and radius             pp
   single point (arg) versus polygon (agent)                             pP
   polygon (arg) versus single point (agent) [possibly with radius?]     Pp
X	polygon (arg) versus versus polygon (agent)                           PP

	point-list (arg) versus single point (agent) and radius               p*p
	single point (arg) versus point-list (agent) and radius               pp*
	point-list (arg) versus point-list (agent) and radius                 p*p*
   point-list (arg) versus polygon (agent)                               p*P
   polygon (arg) versus point-list (agent) [possibly with radius?]       Pp*


   NOTE: a polygon passed with a radius makes it look like a point-list!
"


(define (colocated? a b #!optional r) ;; if r is false, point-lists are taken to be polygons
  (or (eqv? a b)
		(let ((pa (point? a))(pb (point? b)))
		  (or (and pa pb r (<= (distance a b) r))
				(let ((Pa (polygon? a)) (Pb (polygon? b)))
				  (or 
					(and (point? a) (polygon? b) (point-in-polygon a b))
					(and (polygon? a) (point? b) (point-in-polygon b a))
					(eqv? a b)))))))

(define (colocated*? s L #!optional r) ;; s is a point, L is a list
		(apply orf (map (lambda (l) (colocated? s l r)) L)))

;; (define (colocated*? s L #!optional r)
;;   (if (and (point? L) (point-list? s))
;; 		(colocated*? L s r)
;; 		(apply orf (map (lambda (l) (colocated? s l r)) L))))	

;; both L1 and L2 are lists 
(define (colocated**? L1 L2 #!optional r)
  (apply orf (apply append (map (lambda (s) (colocated*? s L2)) L1))))

(model-method (<agent> <list>) (locate self Q #!rest args)
  "args are of the form 
   {'*|class|symbol|string|proc|list|bool} [{radius [location|loc-list]}] | {polygon|polygon-list}] ]"

  ;;(dnl* "locate:" (cnc self))

  (if (or (number? (car args)) (polygon%? (car args))) ;; implicit wildcard selector
		(set! args (cons (lambda (x) #t) args)))

  (let* ((selector (cond
						  ((null? args) Q)
						  ((null? (car args)) '())
						  ((eqv? args '(#t)) (list-copy Q))
						  (else (car args))))
			(radius (if (and (not (null? (cdr args))) (number? (cadr args))) (cadr args) #f))
			(poly (if (and (not (null? (cdr args))) (not radius) (polygon%? (cadr args))) (cadr args) #f))
			(loc (if (and radius (not (null? (cddr args))) (or (point-list? (caddr args)) (point? (caddr args)))) (caddr args) #f))
			)
	 (if (eq? '* selector) (set! selector (lambda (x) #t)))
	 
	 (let ((result 
			  (cond
				((null? args) Q)
				((null? (car args)) '())
				((eqv? args '(#t)) (list-copy Q))
				((and (class? selector) (not radius) (not poly)) (filter (*is-class? selector) Q))
				((and (symbol? selector) (not radius) (not poly)) (filter (*provides? selector) Q))
				((and (string? selector) (not radius) (not poly)) (filter (*is-taxon? selector) Q))
				((and (procedure? selector) (not radius) (not poly)) (filter selector Q))
				((<= (length args) 1) (error "bad argument to kernel call 'locate -- single argument not matched" args))

				
				;; (kernel '(provides vegetation)) or  (kernel '(isa? "adult-herbivore" "carnivore" <example-plant>))
				((and (list? selector) (eq? (caar args) 'provides?)) (filter (apply *provides-*? selector) Q))
				((and (list? selector) (eq? (caar args) 'isa?)) (filter (apply *is-*? selector) Q))
				((and (number? (car args)) (point? (cadr args)))
				 ;; radius and location
				 (filter (lambda (x)
							  (let ((d (query x -kernel- 'distance (car args) (cadr args))))
								 (pp d)
								 )
							  Q)
							))

				((< (length args) 2) (error "bad arguments to kernel call 'locate -- could not match two args" args)) 

				((and (boolean? selector)
						(number? radius)
						(point? loc))
				 (filter (lambda (x) (if (has-slot? x 'location) 
												 (let ((cloc (location x)))
													(if (point? cloc)
														 (colocated? cloc loc radius)
														 (colocated*? loc cloc radius)))
												 selector)) Q))

				((and (boolean? selector)
						(number? radius)
						(point-list? loc))
				 (filter (lambda (x) (if (has-slot? x 'location)
												 (let ((cloc (location x)))
													(if (point? cloc)
														 (colocated? cloc loc radius)
														 (colocated**? loc cloc radius)))
												 selector)) Q))

				((and (boolean? selector) poly)
				 (filter (lambda (x) (if (has-slot? x 'location)
												 (let ((cloc (location x)))
													(if (point? cloc)
														 (colocated? cloc poly)
														 (apply orf (map (lambda (y) (colocated? y poly)) cloc))))
												 selector)) Q))
				
				((not (boolean? selector))
				 (apply locate self (list (locate self Q selector)) #t (cdr args)))

				(else (error "Unrecognised arguments!" args))
				)
			  ))

		(denull-and-flatten result)
		))
  )

;; Contrived example: 
;; (best-N 17 <= (lambda (x) x)
;;    (map (lambda (x) (random-integer 200)) (seq 200)))


(define (add-thing-to-location self entity location)
  ;(UNFINISHED-BUSINESS "Need to flesh this out")
  #t
  )

(define (remove-thing-from-location  entity location)
  ;(UNFINISHED-BUSINESS "Need to flesh this out")
  #t
  )
(define (split-location-tree)
  ;(UNFINISHED-BUSINESS "Need to flesh this out")
  #t)
			


(definition-comment 'run-agent
"Dispatches a call to the agent through the 'run' routine (found at
the end of the 'remodel-methods.scm' file). It also handles special
requests from the agent like mutation and spawning.  The handling of
an agent's time step is done in 'run' rather than here; this routine
is more concerned with constructing the scaffolding for communication 
with the kernel calls and the management of the contents of the queue
as a whole (apart from the basic queue insertion).

This routine returns the runqueue -- the runqueue may be radically 
different than the one passed in, particularly if there is a lot of
breeding/death or  monitors have changed representations of 
components.

run-agent begins by checking the queue-state of the agent, only
'running 'ready-to-run states are accepted.

A copy of the incoming queue is made and the agent is removed from the
head of the queue.  and a flag is set to indicate that the model-body
has not completed its run.

The execution enters a let* and constructs a lambda for making calls
to the 'kernel'.  The second definition is assigned a value computed
with a (cond ...) which catches invalid entries, allows agents to be
'suspended' (by which we mean that they consume time, but do nothing
--- perhaps the state ought to be called 'sinecured')

If the head of the list is indeed an agent, the routine immediately
calls

   (run process t stop kernel) 

where 'kernel' is the previously constructed call into the kernel, and
process is the agent to be run, the value returned from this call is
then assigned to 'return.  If the head isn't an agent, run-agent
assigns the value 'not-an-agent to 'result.

The body of the let* contains another let with a single state variable
whose value is computed in another cond.

The first clause checks to see if the model-body has indicated that
the agent-body has run correctly [(slot-ref self 'agent-body-ran) is
not #f] -- if not, the symbol 'missed-model-body is prepended to the
queue and the queue is passed back up the chain.

If the result is a number, this is assumed to be the amount of time
used, and that execution of the timestep completed correctly.

If the result is a symbol, it is handled like so:

   'ok -- the agent is inserted into the local copy of the queue, and 
          the queue is then returned to the calling closure that assigns 
          the returned list to the model's runqueue 

   'remove -- the local copy of the queue (without the agent which has
          just run) is immediately returned to tha calling closure.

   otherwise the result is prepended to the local copy of the queue and 
          this is then immediately returned to tha calling closure, 
          implicitly dropping the agent from the queue.

A void or null result from a model body is treated like the symbol
'ok, but can be trapped by setting the
trap-model-bodies-with-bad-return-values variable to #t.

A result consisting of a list must have one of the symbols 'spawn,
'introduce 'remove, or 'migrate-representation as the first element
of the list, or it is treated as a fatal error.


'spawn and 'introduce are equivalent and are used to introduce new
agents into the queue.  Each of these agents should be in the
'ready-for-prep state.

The final clause either treats the return value as a fatal error, or
silently reintroduces the agent to the runqueue (one must edit the
code to suppress the error)
"
)
  
(define (agents-dt agent)
  (if (has-slot? agent 'current-interests)
		(modal-dt agent)  
		(slot-ref agent 'dt)))  ;; use modal or default dt


(define KCALL
  ;; This is an "out-of-band" kernel call for code snippets (such as
  ;; the caretaker function), it synthesises an agent of a given class
  ;; with indicated values for state variables and uses that as the
  ;; first argument to the kernel call.  
  ;; (KCALL (list <classtype> 'name nm 'mass ....) callsym args.....)

  (let ((Q '()))
	 (lambda args
		(if (< (length args) 2)
			 (error "Missing arguments!" args))
		(let ((classy (car args))
				(call (cadr args))
				(extras (cddr args))
				)
								
		(if (and (pair? args) (>= (length args) 2))
			 (let ((a (apply make (append (if (list? classy) classy (list classy))
													(list 't global-time	'dt 1)))
						 ))
				(case call
				  ((set-Q!)
					(if (= (length args) 3)	(set! Q (car extras)) (error "bad KCALL 'set-Q" args)))
				  ((clear-Q!) (set! Q '()))
				  ((locate* locate locate<=t locate>=t)
					(apply kernel-call (append (list a Q call) extras)))
				  ((providers? containing-agents)
					(apply kernel-call (append (list a Q call) extras)))
				  ((agent-count) (length Q))
				  ((min-time max-time mean-time)
					(apply kernel-call (append (list a Q call) extras)))
				  ((resource-value)	(apply kernel-call (append (list a Q call) extras)))
				  ((set-resource-value!) (apply kernel-call (append (list a Q call) extras)))
				  ((add-resource-value!) (apply kernel-call (append (list a Q call) extras)))
				  (else (error "bad KCALL" args))
				  )
				)
			 (error "bad KCALL: too few arguments" args)))))
  )


(define run-agent
  (let ((populist '())
		  )
	 ;; Remember the population list across invocations ... (equiv to a "static" in C, folks.)
	 
	 (lambda (t stop run-agent-runqueue . N) ;; This is the function "run-agent"
		(set! N (if (null? N) #f (car N)))

		(KCALL <kernel> 'set-Q! run-agent-runqueue)
		(kdebug 'run-agent "Entering run-agent for " (name (car run-agent-runqueue)) " at " t " to " stop)
		(cond
		 ((or (member (slot-ref (car run-agent-runqueue) 'queue-state) '(terminated)) (not (slot-ref (car run-agent-runqueue)  'may-run)))
		  (hoodoo (car run-agent-runqueue) "run-agent")
		  (kdebug '(run-agent may-not-run terminated) "Dropping " (cnc (car run-agent-runqueue)) (taxon (car run-agent-runqueue)))
		  (cdr run-agent-runqueue)
		  )
		 ((eq? (car run-agent-runqueue) 'mysterious-example-command)
		  (dnl "This sort of thing might be used to inject some sort of limited operation in the queue. No idea how it might actually work.")
		  (cdr run-agent-runqueue))

		 (#t ;; Main processing clause
		  (if (not (isa? (car run-agent-runqueue) <agent>))
				(begin
				  (dnl* "Attempted to run a non-agent!")
				  (abort (car run-agent-runqueue))))

		  (let* ((local-run-agent-runqueue run-agent-runqueue)
					(process (if (and (not (null? local-run-agent-runqueue)) (list? local-run-agent-runqueue)) (car local-run-agent-runqueue) #f)) 
					;; ... either false or the lambda to run
					(queue-state (if process (slot-ref process 'queue-state) #f))
					)
			 (kdebug '(run-agent top-of-the-queue) (cnc (car local-run-agent-runqueue)) (taxon (car local-run-agent-runqueue)) (subjective-time (car local-run-agent-runqueue)) agent-state)
			 (or (eqv? queue-state 'running) ;; if any of the next three steps are true it continues with the next step (the "if")
				  (eqv? queue-state 'ready-to-run)
				  (and (eqv? queue-state 'ready-for-prep)
						 (agent-prep process t end)
						 )
				  (abort (string-append
							 "Attempted to run " 
							 (cnc process) ":"(name process)
							 " when it is in the state " (object->string queue-state))))

			 (if (and process (kdebug? 'running)) (dnl* "Running" (name process) "at" t))

			 ;;(test-queue-size local-run-agent-runqueue N)
			 ;; remove the agent's run request from the top of the queue
			 (set! local-run-agent-runqueue (cdr local-run-agent-runqueue))
			 ;;(test-queue-size local-run-agent-runqueue N)
			 
			 (kdebug 'run-agent "In run-agent")

			 (slot-set! process 'agent-body-ran #f)
			 ;; Mark things as not having run through the body list
			 
			 ;; Here result should be a complex return value, not the
			 ;; number of ticks used.

			 (kdebug 'track-run-agent "####################" (cnc process) "####################")
			 (let* ((kernel
						(lambda x
						  ;;(dnl* "calling kernel with" (cnc process) (name process) x)
						  ;;(dnl* "The queue has" (length local-run-agent-runqueue) "entries")
						  (apply kernel-call (cons process (cons local-run-agent-runqueue  x))))
						)
					  
					  (result (cond
								  ((symbol? process)  'bad-runqueue)
								  ((eqv? queue-state 'suspended)
									;; A suspended agent "consumes" its
									;; time without doing anything, except
									;; update its subj. time.
									(let ((dt (interval t (agents-dt process) stop (slot-ref process 'timestep-schedule)))
											(st (slot-ref process 'subjective-time)))
									  (kdebug '(run-agent suspended) "suspended agent "  (name process))
									  ;; so, we force the agent to believe that it has lived the timestep
									  "In a more comprehensive version, we may have an alternate 'suspended-body' which will"
									  "perform minimal activity in the place of the real model body"
									  (slot-set! process 'subjective-time stop) 
									  'ok)
									)

								  ;; If the thing queued is actually an agent, run the agent
								  ((isa? process <agent>) ;; equivalent to (member <agent> (class-cpl (class-of process)))
									(let ((r (run process t stop kernel))) ;; (run ...) is in remodel-methods.scm [search for 'AGENTS RUN HERE']
									  ;; (dnl* " + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +")
									  ;; (dnl* "run returned " r)
									  (kdebug 'run-agent "Return from (run...):" (cnc r) r)
									  (if (or lookit-running-names (kdebug? 'timing))
											(kdebug 'track-run-agent (slot-ref process 'name)
													  (slot-ref process 'subjective-time)
													  r))
									  (kdebug 'run-agent "finished running "
												 (name process) "@"
												 (slot-ref process 'subjective-time) " and returns " r)
									  r)
									)
								  (#t (dnl "Found a non-agent, dropping it.")
										'not-an-agent)
								  )
								 )
					  )

				(KCALL <kernel> 'clear-Q! run-agent-runqueue) ;; clear the queue used by snippets



				;;(dnl* "RUN-AT RESULT:" result "process:" (agent-state process))
				;; This let must return the "new" runqueue.  Any reinsertions, deletions or new insertions are handled here.
				(let ((return-list
						 (cond
;						  ((not (slot-ref process 'agent-body-ran))
;							(if #t ;; This causes a hard failure if an agent fails to run properly
;								 (error
;								  (string-append
;									"The agent " (cnc process) ":" (name process)
;									" failed to chain back to the base <agent> "
;									"model-body.\n"
;									"This suggest that things have gone very wrong; "
;									"check that there is a call like (call-parents).")
;								  ))
;							(cons 'missed-model-body local-run-agent-runqueue)
;							)

						  ((number? result) 
							;; The result (in this case) is the amount of time used
							;; measured from the subjective-time of the agent.
							;; q-insert knows how to find out "when" the agent is,
							;; and will re-insert it correctly.  subjective-time is
							;; updated
							(set! local-run-agent-runqueue (q-insert local-run-agent-runqueue process Qcmp))
							local-run-agent-runqueue
							)

						  ((symbol? result) ;;----------------------------------------------
							(let ()
							  (cond
								((eqv? result 'ok)
								 (set! local-run-agent-runqueue (q-insert local-run-agent-runqueue process Qcmp))
								 local-run-agent-runqueue)

								((eqv? result 'wait) ;; did not run, already there (temporally)
								 (set! local-run-agent-runqueue (q-insert local-run-agent-runqueue process Qcmp))
								 local-run-agent-runqueue)

								((eqv? result 'remove)
								 (if (eq? (agent-state process) 'dead) (set! Cemetary (cons process Mortuary)))
								 (agent-shutdown process)
								 (set! Mortuary (cons process Mortuary))
								 (set! local-run-agent-runqueue (excise process local-run-agent-runqueue))
								 local-run-agent-runqueue)

								(else 
								 (cons result local-run-agent-runqueue)))
							  ))
						  ((and (not trap-model-bodies-with-bad-return-values)
								  (or (null? result) (void? result) (eq? 'ok? result)))
							(set! local-run-agent-runqueue (q-insert local-run-agent-runqueue process Qcmp))
							local-run-agent-runqueue)
							
						  ((eqv? result #!void)
							(let ((s
									 (string-append "A " (cnc process)
														 " tried to return a void from its "
														 "model-body.  This is an error")))
							  ;;(Abort s)
							  (abort s)
							  ))
						  ((pair? result)
							;;(dnl* "####" (car result))
							(if (kdebug? 'run-agent-result)
								 (begin
									(dnl* "####" (car result))
									(pp (cdr result))))
							
							(case (car result)
							  ;; Remove ===============================================================
							  ('wait ;; did not run, already there (temporally)
								;; (for-each
								;;  (lambda (x)
								;; 	(if (isa? x <agent>)
								;; 		 (begin
								;; 			(slot-set! x  'agent-state 'suspended)
								;; 			(set! local-run-agent-runqueue (q-insert local-run-agent-runqueue x Qcmp))			
								;; 			) )
								;; 	)
								;;  (cdr result))
								
								(set! local-run-agent-runqueue (q-insert local-run-agent-runqueue process Qcmp))
								local-run-agent-runqueue
								)
							  ('remove ;; a list of agents
;								(dnl* "**** REMOVING" (map name (cdr result)))
								(kdebug '(q-manipulation remove) result)
								(if (pair? (cdr result))
									 (let ((Xsection (intersection (cdr result) local-run-agent-runqueue)))		  
										(set! local-run-agent-runqueue (!filter (lambda (x) (member x Xsection))	local-run-agent-runqueue)))
									 (set! local-run-agent-runqueue (!filter (lambda (x) (eqv? x process)) local-run-agent-runqueue))
									 )
								local-run-agent-runqueue
								)
							  ;; Migrate to a different model representation ==========================
							  ;; model migration implies correct execution of the timestep
							  ('migrate ;; replace an agent with list of one or more agents
								(dnl* "This is probably wrong here....")
								(kdebug '(q-manipulation migrate) result)
								(let* ((result (cadr result)))
								  (for-each
									(lambda (x) ;; insert all component agents for new representation
									  (if (isa? x <agent>)
											(begin
											  (agent-prep x t end)
											  (set! local-run-agent-runqueue (q-insert local-run-agent-runqueue x Qcmp)))))
									result))
								local-run-agent-runqueue) ;; end of the migration clause

							  ;; Spawn  ==========================
							  ;; insert spawned offspring into the system, the agent handles the creation
							  ;; of the offspring (appropriately enough)
							  ((spawn introduce) ;; There are multiple tags here so that
								;; we can make the *calling* code clear.  Also note that 
								;; Spawning implies correct execution of the timestep
								(kdebug '(q-manipulation spawn introduce) result)
								;;(dnl* '**** '(q-manipulation spawn introduce) result)


;								(dnl* "**** INTRODUCING " (map name (cadr result)))

								(let* ((induct (lambda (x)
													 (if (isa? x <agent>)
														  (begin
															 (agent-prep x t end)
															 (set! local-run-agent-runqueue
																	 (q-insert local-run-agent-runqueue x Qcmp))))))
										 )

								  (cond
									((list? (cadr result)) (for-each induct (cadr result)))
									((agent? (cadr result)) (induct (cadr result))
									 result)
									)
								  )
								
								;; Something like salmon will flag themselves as dead in their final spawning tick
								;; 'terminated indicates that the agent should be removed, 'dead will be reinserted 
								(if (not (eq? (slot-ref process 'queue-state) 'terminated)) ;;(not (member (slot-ref process 'queue-state) '(terminated)))
									 ;; Either insert the agent into the runqueue again, or into the Mortuary
									 (set! local-run-agent-runqueue (q-insert local-run-agent-runqueue process Qcmp))
									 (begin
										(shutdown-agent process)
										(set! Mortuary (cons process Mortuary))))
								local-run-agent-runqueue
								)
							  
							  ('modify ;; expects (cadr result) to be a list of commands, such as (list ('remove ...) ('add ...))
								(for-each
								 (lambda (result)
									(case (car result)
									  ('remove
										(kdebug '(q-manipulation remove) result)
										(let ((Xsection (intersection (cdr result) local-run-agent-runqueue)))		  
										  (!filter (lambda (x) (member x Xsection))	local-run-agent-runqueue)
										  ))
									  ('migrate ;; replace an agent with list of one or more agents
										(kdebug '(q-manipulation migrate) result)
										(for-each
										 (lambda (x) ;; insert all component agents for new representation
											(if (isa? x <agent>)
												 (begin
													(agent-prep x t end)
													(set! local-run-agent-runqueue (q-insert local-run-agent-runqueue x Qcmp)))))
										 (cdr result))
										)
									  ((spawn introduce) ;; There are multiple tags here so that
										;; we can make the *calling* code clear.  Also note that 
										;; Spawning implies correct execution of the timestep
										(kdebug '(q-manipulation spawn introduce) result)
										(for-each
										 (lambda (x)
											(if (isa? x <agent>)
												 (begin
													(agent-prep x t end)
													(set! local-run-agent-runqueue (q-insert local-run-agent-runqueue x Qcmp)))))
										 (cdr result))
										)
									  (else (error "Bad command passed to 'modify in the kernel" (abort))))
									)
								 (cadr result))
								)

							  (else ;;(error "The frog has left the building!" (car result))
								(if (list? result) ;; probably parent returns
									 (begin
										(if trap-model-bodies-with-bad-return-values
											 (set! result (denull-and-flatten result))
											 (set! result (map (lambda (x) (if (or (null? x) (void? x)) 'ok x)) (denull-and-flatten result)))))
									 )
								
								(cond
								 ((or (null? result)
										(void? result))
								  (dnl* "#!void or null returned by the model body of" (name process)
										  " ... assuming that it ran correctly")
								  (set! local-run-agent-runqueue (q-insert local-run-agent-runqueue process Qcmp)))
								 (else
								  ;;(dnl* "Inconceivable!"  (cnc process) (name process)  (string-append "[" (number->string t)", "(number->string stop)"]") (subjective-time process) '--> result)
								  (set! local-run-agent-runqueue (q-insert local-run-agent-runqueue process Qcmp))
								  )
								 ); cond
								); (else
							  ) ; case (car result)
							) ; cond clause: (pair? result)
						  (#t
							(if #t (error "We really should not be here...."))
							(set! local-run-agent-runqueue (q-insert local-run-agent-runqueue process Qcmp))
							)
						  ); (cond ...
						 )) ;; let ((...))


				  ;;(test-queue-size return-list N)
				  (kdebug 'run-agent "Finished with run-agent" (name process)
							 "@" (slot-ref process 'subjective-time))
				  ;; *********** THIS IS NOT THE ONLY WAY TO DO THIS **************
				  ;; One might need to have a method that will take a kernelcall procedure from
				  ;; another agent if there is out-of-band activity that requires a kernelcall.
				  ;; This is the conservative option.
				  
				  local-run-agent-runqueue
				  ) ; end of let
				)  ; end of let*
			 ) ; end of let*
		  ) ; (#t ...
		 ) ;; end of cond
		) ; end of lambda
	 ))
  

(definition-comment 'run-simulation
  "Q is the preloaded run-queue"
  "Start and End are numbers s.t. Start < End")
(define (run-simulation Q Start End . close-up-shop) 
  (prep-agents Q Start End)

  (set! Q (queue Start End Q))

  ;; We don't shut down just now, we are still developing
  (if (not developing) (agent-shutdown Q))

  (if (and (not (null? close-up-shop)) (procedure? (car close-up-shop)))
      ((car close-up-shop)))
  )

(definition-comment 'continue-simulation
  "Q is the currently running list of agents (run-queue)"
  "End is a number that indicates the end of everything are numbers s.t. Start < End"
  "close-up-shop is a procedure taking no arguments that may be run at the end.")
(define (continue-simulation Q End . close-up-shop) 
  (set! Q (queue (slot-ref (car Q) 'subjective-time) End Q))
  (if (and (not (null? close-up-shop)) (procedure? (car close-up-shop)))
      ((car close-up-shop)))
  )




(define (locate-pp Q r p #!optional dflt)
  (filter (lambda (q) (cond
							  ((point? q) (<= (distance p q) r))
							  ((and (agent? q) (has-slot? q 'location)) (<= (distance p (location q)) r))

							  (else dflt)))
			 Q))

(define (locate-pP Q p #!optional dflt)
  (filter (lambda (q) (cond
							  ((point-list? q) (point-in-polygon p q))
							  ((and (agent? q) (has-slot? q 'perimeter)) (point-in-polygon p (perimeter q)))
							  (else dflt)))
			 Q))

(define (locate-Pp Q p #!optional dflt)
  (filter (lambda (q) (cond
							  ((point? q) (point-in-polygon q p))
							  ((has-slot? q 'location) (point-in-polygon (location q) p))
							  (else dflt)))
			 Q))

(define (locate-p*p Q r p #!optional dflt)
  (sortless-unique
	(apply append (map (lambda (x) (apply append (map (lambda (q) (locate-pp L r x q)) Q))) p))))

(define (locate-pp* Q r p #!optional dflt)
  (sortless-unique
	(apply append (map (lambda (x) (apply append (map (lambda (q) (locate-pp L r x q)) Q))) p))))




;-  The End 

;;; Local Variables: 
;;; comment-end: ""
;;; comment-start: "; "
;;; mode: scheme
;;; outline-regexp: ";-+"
;;; comment-column: 0
;;; End:

