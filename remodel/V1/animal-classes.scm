;-  Identification and Changes

;--
;	animal-classes.scm -- Written by Randall Gray 

;-  Code 

(define <simple-metabolism> (make-class (list <object>) '(days-of-hunger hunger-limit)))
(register-class <simple-metabolism>)

(define <metabolism> (make-class (list <object>) '(stomach-contents 
																	mass
																	structural-prop             ;; structural-mass increases as mass increases -- all things that have metabolism must have mass
																	structural-mass             ;; kg
																	max-consumption-rate        ;; the maximum amount it could eat in a given period, assuming an infinite stomach
																	metabolic-rate              ;; the amount of "stuff" or "stuff-equivalent" needed per kg per unit of time
																	starvation-level            ;; the animal dies if mass/structural-mass goes below this value 
																	gut-size                    ;; stomach capacity as a proportion of structural-mass
																	condition                   ;; "fat" reserves
																	food->condition-conversion-rate   ;; exchange rate between stomach-contents and condition (* condition condition-conversion-rate) ~ stomach-contents
																	condition->food-conversion-rate   ;; exchange rate between stomach-contents and condition (* condition condition-conversion-rate) ~ stomach-contents
																	food->mass-conversion-rate        ;; exchange rate between stomach-contents and body mass (* delta-mass mass-conversion-rate) ~ stomach-contents
																	mass->food-conversion-rate        ;; exchange rate between stomach-contents and body mass (* delta-mass mass-conversion-rate) ~ stomach-contents
																	condition-conversion-rate   ;; exchange rate between stomach-contents and condition (* condition condition-conversion-rate) ~ stomach-contents
																	mass-conversion-rate        ;; exchange rate between stomach-contents and body mass (* delta-mass mass-conversion-rate) ~ stomach-contents
																	max-growth-rate             ;; the most it will grow in a time period (uses mass-conversion-rate
																	max-condition-rate          ;; the most it will increase its condition in a time period (uses condition-conversion-rate -- defaults to mgr
																	)
											))
(register-class <metabolism>)

;; structural-mass is pegged at (max (* (my 'mass) (my 'structural-prop))) through time
;; structural-prop is multiplied by (my 'mass) to give a number less than or equal to the structural mas
;; metabolic-rate: (* metabolic-rate (my 'mass) dt) is the mass required to maintain body mass for dt
;; ... consumption above that rate is converted to "condition"
;; == _ 
;;   |  base-rate is the amount of mass removed per dt for stomach contents
;;   |_ condition-rate is the amount of mass removed per dt for conditon contents
;;
;; starvation-rate is the amount of body mass removed per dt
;; starvation-level is the value of (/ (my 'mass) (my 'structural-mass)) at which an organism dies.  This  really ought to be a number like 1.3
;; stomach-contents is an absolute amount of food
;; gut-size is a scalar multiplier of the structural-mass which indicates the max cap. of the stomach
;; condition is an absolute number which is equivalent to mass in the stomach
;; food->condition-conversion-rate is the efficiency of conversion from stomach food to condition food
;; condition->food-conversion-rate is the efficiency of conversion from condition to food
;; food->mass-conversion-rate is the efficiency of conversion from stomach food to mass food
;; mass->food-conversion-rate is the efficiency of conversion from mass to food
;; max-consumption-rate is the rate at which things can move through the system

(define <simple-animal> (make-class (list <simple-metabolism> <thing>) '(age sex habitat searchradius 
																									  foodlist homelist breedlist
																									  domain-attraction
																									  food-attraction
																									  ))
  ) ;; lists of attributes it looks for for eating, denning and breeding
(register-class <simple-animal>)


;; current-interest is a function which takes (self age t dt ...) and returns a meaningful symbol
;; 

(define <animal> (make-class (list <metabolism> <thing>) ;; lists of attributes it looks for for eating, denning and breeding
									  '(current-interest age sex
																habitat searchradius foodlist homelist breedlist
																movementspeed
																searchspeed 
																foragespeed
																wanderspeed
																objective
																domain-attraction
																food-attraction
																near-food-attraction
																)
				  
				  ))
(register-class <animal>)

;-  The End 


;;; Local Variables:
;;; mode: scheme
;;; outline-regexp: ";-+"
;;; comment-column:0
;;; comment-start: ";;; "
;;; comment-end:"" 
;;; End:
