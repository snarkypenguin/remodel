(include "framework")

		
(declare-method add! "add!")
(declare-method add-fruit "adjusts the number of fruit in a cell")
(declare-method add-patch "add a patch to a habitat")
(declare-method add-patches "add a list of patches to a habitat")
(declare-method add-service "add-service")
(declare-method age "return the age of the animal")
(declare-method aggregate-value "aggregate-value of a services within a nominated circle")
(declare-method capacity "returns the carrying capacity of an ecoservice")
(declare-method centre "returns the centre/centroid of an object")
(declare-method change-territory "move to another region (change cells)")
(declare-method crowded? "determine if the region is too crowded for the animal")
(declare-method define-population-dynamics! "Sets things up for population dynamics using definitions, alternative to set-population-dynamics!")
(declare-method define-system-dynamics! "specifies a system of differential equations")
(declare-method die "routine corresponding to the death of an animal (calls shutdown)")
(declare-method dimensions "returns the number of dimensions")
(declare-method disable-all-service-growth! "disables the service level growth model for the dynamic-patch")
(declare-method disable-growth! "disables the growth model for the ecoservice/patch/etc")
(declare-method disable-service-growth! "disables the service level growth model for for a service in the dynamic-patch")
(declare-method distance-to-boundary "returns the distance to a boundary")
(declare-method distance-to-centre "distance-to-centre")
(declare-method distance-to-interior "distance-to-interior")
(declare-method eat "add food to the stomach, process food from the stomach, grow, return the amount eaten")
(declare-method eat "Eat food ")
(declare-method enable-all-service-growth! "enables the service level growth model for the dynamic-patch")
(declare-method enable-growth! "disables the growth model for the ecoservice/patch/etc")
(declare-method enable-service-growth! "enables the service level growth model for a service in the dynamic-patch")
(declare-method forage "move about looking for a region with food")
(declare-method fruit-count "returns the number of fruit produced by an agent")
(declare-method growth "does the business of growing")
(declare-method growth-model "returns the growth model for the ecoservice/patch/...")
(declare-method install-boundary "set/reset the boundary for a patch")
(declare-method max-bound "max-bound")
(declare-method maxima "returns the maxima for the ordinates")
(declare-method mean-value "mean value of a resource or service")
(declare-method min-bound "min-bound")
(declare-method minima "returns the minima for the ordinates")
(declare-method my-rep "returns the underlying agent which defines the domain")
(declare-method ordinates "returns the indices for a given location")
(declare-method origin "returns the origin")
(declare-method patch-at "returns a list of any patches containing a supplied location")
(declare-method patch-list% "return a list of all patches or only the ones with particular services")
(declare-method plant-radius "returns the radius of the plant")
(declare-method populate-cells "sets up the cell agents")
(declare-method prey-present "returns a list of the animal's prey in a suitable locality")
(declare-method radius "inner radius (inscribed circle)")
(declare-method Radius "outer radius (containing circle)")
(declare-method random-point "returns a random point within the object")
(declare-method remove-patch "remove a patch from a habitat")
(declare-method remove-service "remove-service")
(declare-method rep "returns the representation object")
(declare-method reproduce "create offspring")
(declare-method rvalue "returns the r value (sharpness or exponent) of an ecoservice's growth model")
(declare-method scale "returns the scale vector or the scale associated with a nominated ordinate")
(declare-method scale! "scale!")
(declare-method service-list-index "returns the index of a species in the species list")
(declare-method service-list% "service-list%") ;; returns value
(declare-method service-matrix-index "returns the index of a species in the species matrix")
(declare-method service? "service?")
(declare-method service "service") ;; returns value
(declare-method service-sites "returns the list of patches with particular services")
(declare-method services% "services") ;; returns value
(declare-method service-values "values of species/services (aggregates things with the same id)") ;; returns value
(declare-method set-age! "set the age of the animal")
(declare-method set-centre! "returns the centre/centroid of an object")
(declare-method set-population-dynamics! "Sets things up for population dynamics using differential equations and rk4*")
(declare-method set-radius! "sets the radius for circles")
(declare-method set-services! "set-services!") ;; sets value
(declare-method set-sex! "set the sex of the animal")
(declare-method set-system-dynamics! "(re)set the system of equations in a diffeq-system")
(declare-method set-value! "set-value!")
(declare-method sex "return the sex of the animal")
(declare-method spatial-scale "an indication of some 'natural scale' of the habitat based on the dist between patches")
(declare-method specific-services% "names of species (or services)") 
(declare-method total-capacity "returns the total capacity of all the niches")
(declare-method value "value")
(declare-method wander-around "Wander around with a bias toward a nomintated point")
;;; Local Variables:
;;; mode: scheme
;;; outline-regexp: ";-+"
;;; comment-column:0
;;; comment-start: ";;; "
;;; comment-end:"" 
;;; End:
