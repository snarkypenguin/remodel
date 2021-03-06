
(include "remodel-framework")
;- Identification and Changes

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




"The basic classes from which the others are ultimately derived are
kept in 'sclos+extn.scm' since they are supposed to be /fundamental/."


;- Load initial libraries 

;-- Define/allocate new classes

;--- substrate


;;; ;--- agent based classes

;;; (define-class <agent>
;;;   (inherits-from <object>)
;;;   (state-variables name taxon representation agent-state
;;; 						 note
;;; 						 kernel
;;; 						 subjective-time priority jiggle 
;;; 						 dt
;;; 						 migration-test timestep-schedule counter
;;; 						 projection-assoc-list local-projection inv-local-projection
;;; 						 state-flags
;;; 						 agent-epsilon
;;; 						 agent-schedule
;;; 						 dont-log
;;; 						 agent-body-ran

;;; 						 ;; acting as a kernel for others
;;; 						 suspended-at
;;; 						 subsidiary-agents active-subsidiary-agents

;;; 						 ;;
;;; 						 maintenance-list
;;; 						 )
;;; 	)


;; subsidiary-agents are run within the time-step and auspices of
;; another (presumably related) agent. Agents may know what their
;; parent agent is (if they have one) and may indicate to the parent
;; that they should be added to the active list. The parent agent is
;; the one that actually decides if a agent is to move into the active
;; queue or out of the active queue.  Whe things get moved, "value"
;; from the parent is moved into the relevant sub-agents.  The set of
;; ecoservices of the parent contains all of the types represented in
;; its sub-agents.
;;
;; priority is an integer, the higher the integer the greater the
;; priority.  The default value is zero jiggle is a real number in (0,
;; 1).  Setting jiggle to values outside that domain suppresses the
;; the randomisation of the jiggle.  If an agent has a timestep-schedule,
;; then it WILL be used in determining the next dt.

;; name is a string
;; representation is a symbol
;; subjective-time, and dt are numbers representing a time and an interval,
;; body is a function (lambda (self t df . args) ...)
;; migration-test is a function (lambda (self t df . args) ...)
;; timestep-schedule is a list of times at which the agent needs to run
;;    (a list of monotonically increasing numbers)
;; kernel is a function that can be used to interact with
;;    the kernel of the simulation


;;;(load "monitor-classes.scm")
;;;(load "log-classes.scm") ;; These are used to generate output.

(define-class <projection>
  (inherits-from <object>)
  (state-variables projection-assoc-list
						 local->model model->local
						 ))
"The model->local is a projection used to map model coordinates
into agent's *internal* coordinates.  There must also be a
corresponding local->model to map the other
direction"


(define-class <plottable>
  (inherits-from <projection>)
  (state-variables location direction
						 always-plot
						 default-location-type
						 default-font default-size 
						 default-color
						 map-color map-contrast-color
						 glyph plot-scale
						 ))
;; glyph is either one of the special symbols 'circle 'diamond 'square
;;       '+cross 'Xcross [NYI], or the symbol 'ruler which constructs a
;;       ruler |-----| [NYI] which is oriented according to the
;;       direction vector and is plot-scale units long

;;   a symbol indicating the slot which has the radius of a circle to be plotted
;;   a point-list (centred on zero) and notionally facing North
;;   a function of no arguments used to generate a point list
;;   a real number indicating the radius of a circle with 24 facets
;;   a complex number of the form rad+i*facets                           [NYI]

;; plot-scale can be a scalar, a symbol or a function
;;    a scalar is a simple multiplier, a symbol is a slot containing a multiplier,
;;    a function is passed self and  returns a scalar

;***************   Remember, <agent> is defined in sclos+extn.scm   ***************

(define-class <service-agent>
  (inherits-from <agent>)
  (state-variables
	running-externally ;; #t/#f
	external-rep-list ;; used to point to external represetations (usually IBM/ABM)
	;; The external representation list for external agents that comprise the service
	;; -- this is often #f for things like "grass" or "water" since the ecoservice is
	;;    modelled entirely within this agent
	ext-get  ;; the method or function to use to get data from a member of the external-rep-list
	ext-set! ;; analogous to ext-get, but for setting the value of the member
	name ;; Used in output
	sym ;; symbol (possibly used in updates by other agents
	value ;; current value of the ecoservice
	delta-T-max ;; largest stepsize the ecoservice can accept
	history      ;; maintains  ((t value) ...)
	))
					  




;;; (define-class <file>
;;;   (inherits-from <projection>) ;; there must be support for an mapping into output space
;;;   (state-variables file filename))

;;; (define-class <output>
;;;   (inherits-from <file>)
;;;   (no-state-variables)
;;;   )

;;; (define-class <output*>
;;;   (inherits-from <output>)
;;;   (state-variables basename filetype filename-timescale)
;;;   )

;;; (define-class <input>
;;;   (inherits-from <file>) ;; there must be support for an input mapping into modelspace
;;;   (no-state-variables)
;;; )

;;; (define-class <txt-output>  ;; one big file
;;;   (inherits-from <output>)
;;;   (no-state-variables)
;;;   )
					  
;;; (define-class <txt-output*> ;; small files
;;;   (inherits-from <output*>)
;;;   (state-variables))
					  
;;; (define-class <tbl-output>
;;;   (inherits-from <output>)
;;;   (state-variables fields types))

;;; (define-class <tbl-output*>
;;;   (inherits-from <output*>)
;;;   (state-variables fields types))

;;; (define-class <ps-output>
;;;   (inherits-from <output>))
					  
;;; (define-class <ps-output*>
;;;   (inherits-from <output*>))


(define-class <diffeq-system>
  (inherits-from <agent>)
  (state-variables
	variable-names        ;; list of strings associated with each value
	variable-values       ;; list of strings associated with each value
	variable-symbols      ;; unique symbols for each of the values
	d/dt-list             ;; differential equations which describe the dynamics
	subdivisions          ;; Number of intervals a given dt is subdivided into
	variable-values       ;; the list of symbol+values returned from get-externals
	                      ;; or from P
	get-externals         ;; a list of symbol+functions which return the current 
	                      ;; state of the external variables
	external-update       ;; an a-list of symbol+functions which update the external
                         ;; variables			
	domains               ;; List of predicates that define the domains of each of the
	                      ;; variables (returns #f if the value is outside the domain)

   ;;; The order of all the preceeding lists must be consistent. There is no way for
	;;; the code to ensure that this is so.  Be warned.

	;; An alternate representation for input
	variable-definitions  ;; list of the form ((nameA dA/dt) ...)  or (nameZ agent accessor)

	too-small             ;; time steps smaller than this cause an abort
	epsilon               ;; for little things
	do-processing         ;; if #f, no processing is done at all

	P                     ;; This is generated using rk4* and d/dt-list
	;; The functions can return either the value passed in, #f or a "clipped value"
	;; a boolean false indicates a catastrophic failure, a clipped value keeps things
	;; going (restricted to the domain) otherwise it just acts like the (lambda (x) x)
	))

(define-class <general-array>
  (inherits-from <agent> <projection>) ;; We inherit from projection so that we may pass this as a target for <log-map>
  (state-variables

	;; 
	assessment-rep ;; typically fine unless the number of elements drops too low or too high
	assessment-collection 
	assessment-taxon
	assessment-niche
	assessment-conf
	
	max-records ;; Maximum number of records permitted
	test-subject
	;; This is actually an agent of another sort, such as <plant>, which we can assign values to
	;; if we want to call methods from its corpus.
	
	data-names
	;; slots can be thought of as the "header" which associates the elements of 
	;; the lists in data with their roles

	data
   ;; data is a list of lists, each of which will be of a consistent form
))

(define-class <array>
  (inherits-from <general-array> <plottable>) ;; We inherit from projection so that we may pass this as a target for <log-map>
  (state-variables
	refresh-boundaries
	hull               ;; bounding box, better if we get a convex-hull working
	centre radius      ;; much quicker than point-in-polygon
))

(define-class <proxy> ;; the proxy shares data and data-names with the array, but ONLY has access to one element
  (inherits-from <agent>)
  (state-variables super getter setter @setter @getter)
  ;; setter and getter are "simple",  @setter and @getter do more dereferencing
)

;;; (define-class <mem-agent>
;;;   (inherits-from <agent>)
;;;   (state-variables memory)

(define-class <tracked-agent>
  (inherits-from <agent> <plottable>)
  (state-variables track track-state track-state-vars
						 multiplicity 
						 dim
						 speed max-speed
						 tracked-paths 
						 track-datum ;; a value to be emitted with the track or #f
						 ))
;; "track" will either be a list like (... (t_k x_k y_k) ...) or false
;; "tracked-paths" is a list of non-false traces or false This is the
;; basic class to derive things that have a memory of their past.
;; glyph is either a point list which notionally faces "east" a number
;; which indicates the number of facets in a regular polyhedron, or a
;; procedure which returns a point-list.  It is the responsibility of
;; the agent to update the plot magnification appropriately.

(define-class <thing>
  (inherits-from <tracked-agent>)
  (state-variables mass))

(define-class <living-thing>
  (inherits-from <thing>)
  (state-variables
	ndt ;; nominal timestep for movement/decision making.  Used in the wander-around method
	dead-color
	age
	age-at-instantiation ;; the age at which something is "born"

	longevity ;; used for calculating the mass-at-age curve -- equivalent to the max-age of the species
	max-age	;; This is either a precalculated hard-kill (corresponds, to genetic influence?) or a non-number
	probability-of-mortality ;;; a number [typically compared against a (random-real) call] or a
	                         ;;; procedure that takes the age of the entity and returns a number

	reproduction-age         ;;; age at which reproduction can first occur
	reproduction-cycle       ;;; total length of cycle (including fallow period)  for annual breeders this is (* 1 year)
	reproduction-offset      ;;; offset from the start of the reproductive cycle before the reproduction-period
   reproduction-period      ;;; period during which reproduction (fruiting, birth) occurs
	reproduction-probability ;;; prob of success
	
	decay-rate ;; when it's no longer living
	mass-at-age ;; not optional    but the growth will, so an entity that misses out on a bursty period
					;; will always be smaller than others in its cohort
	landscape  ;; an landscape agent that encompasses a number of potential domains
	         ;;    or a list that does the same thing ... not currently used
	domain   ;; an environment of some sort (they have to live somewhere!)
	next-env-check ;; the time the next environment check ought to occur
	env-check-interval ;; should be a multiple of the timestep
	environmental-threats ;; list of environmental conditions or entities that may be threatening.
	;; In this instance, we might have bounding regions which indicate prevailing conditions (fire, flood...)
	;; and may change fairly rapidly.  In the presence of environmental threats, the animals probably need
	;; a very short timestep.
	))

(define-class <environment>
  (inherits-from <agent> <plottable>)
  (state-variables default-value minv maxv inner-radius outer-radius rep)
  ;; minv and maxv form a bounding volume in however many dimensions
  ;; rep is usually something like a polygon, a DEM or something like that 
  )

(define-class <blackboard>
  (inherits-from <agent>) ;; 
  (state-variables label message-list))
  

(define-class <model-maintenance>
  (inherits-from <object>) ;; We have <projection> since I'd really rather not have two distinct maintenance classes
  (state-variables maintenance-list I-need))
;; I-need is a list of fields which comprise the env-vector, and must be filled in by the
;;   agent which is maintaining the reduced model.
;; Agents with a model-maintenance class must supply state-variables and a method to update them
;; the form for the function is (update-state self t dt)
;; 



;;; Local Variables:
;;; mode: scheme
;;; outline-regexp: ";-+"
;;; comment-column:0
;;; comment-start: ";;; "
;;; comment-end:"" 
;;; End:




