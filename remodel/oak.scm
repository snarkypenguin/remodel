; -*- mode: scheme; -*-
;-  Identification and Changes

;--
;	oak.scm -- Written by Randall Gray 
;	Initial coding: 
;		Date: 2017.03.29
;		Location: zero:/home/randall/Thesis/Example-Model/model/oak.scm
;
;	History:
;

;-  Copyright 

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


;-  Discussion 

;-  Configuration stuff 

;-  Included files 

;-  Variables/constants both public and static

;--    Static data

;--    Public data 

;-  Code 

"
Oak tree from https://sylvia.org.uk/oneoak/treefacts.php

Tree height 23.9m
Age 222 years
Stem diameter 89.8cm
Crown diameter 17.8m
Timber height 12.9m
Timber volume 4.96m3
Leaf area index 1.7
Tree weight 14.385 tonnes
	 The complete weight details:
	 Stem to timber height 	6,036kg
	 Branchwood to 7cm 	6,137kg
	 Branchwood 7 - 4cm 	1,000kg
	 Lop & top < 4cm 	1,212kg
	 Total Weight 	14,385kg
Tree volume 11.58 m3 (wood for parts greater than 7cm dia)
Dry mass 7.86 tonnes
Carbon content 3.93 tonnes


Also 

... transpiration figures vary a lot depending on local
climate type, current weather (humidity etc), availability of water,
exact tree size, tree variety, etc

    a large oak tree can transpire 40,000 gallons of water per year

vccs.edu

There are about 240 US Gallons of water in a ton. SO the above figure
equates to an average of about 0.45 tons of transpired water a day for
a full canopy. However, trees in temperate climates are much more
active in summer than in winter, so the peak daily value might be
several times higher.

    the full-grown oak (Quercus robur L.) tree ... [has] sap flow rate
values ... of up to 400 Kg per day ... 100 years of age, 33 m height.

Sap Flow Rates and Transpiration Dynamics in the Full-Grown Oak ...

400 Kg is about 0.44 tons or exactly 0.4 tonnes.


So, early in life, the height increases faster than mass, but later
(when gravity calls to collect the bill), mass must increase faster, 
... we'll consider a relationship like

   h ~ K sqrt(m)

for a suitable K.  For oaks, K might be 0.19176657111268274052, if we
use the oneoak example.  This overestimates the mass of very small
trees(a 30cm plant has a putative mass of ~2.25kg).
This is probably not  enough to wreck our plaything.

However, since the cube root of the tree's mass is remarkably close to
its height, and this relation give a mass of 670.g for a 30cm tree;
this seems a simpler basis from which to work.

Now let's consider the radius of the tree (above and below). From the
data, it looks as though a radius which is 3/8 * h may be close enough.

"


(define (general-leaf-area mass lai)
  (* lai pi (sqr (plant-mass->radius mass))))

(define (plant-leaf-area p) ;; leaf area
  (general-leaf-area (slot-ref p 'mass) (slot-ref p 'lai)))

(define (plant-mass->height m) ;; given mass
  (power m 1/3))
 ;; h = m^{1/3}

(define (plant-height->mass h) ;; given height
  (power h 3))
 ;; h = m^{1/3}

(define (plant-mass->radius m) ;; given mass
  (* 3/8 (power m 1/3)))
;; r = 3/8 * m^{1/3}

(define (mass->half-sphere-area m) ;; given mass
  (let ((pi (acos -1.0)))
  (* 9/32 pi (power m 2/3))))
;; half the area of a sphere
;; A = 1/2 * 4 pi r^2
;;   = 2 pi (3/8 m^{1/3})^2
;;   = 9/32 pi m^{2/3}

(define (mass->half-sphere-vol m) ;; given mass
  (let ((pi (acos -1.0)))
  (* 9/256 pi m)))
;; half the volume of a sphere (since leaves aren't just at the
;; margins, L is a const

;; A = 1/2 L 4/3 pi r^3
;;   = 1/2 L pi 4/3 (3/8 * m^{1/3})^3
;;   = 1/2 4/3 (3/8)^3 L pi m
;;   = 9/256 L pi m

;; which indicates that the leaf area is proportional to the mass of
;; the tree ...  Since L is just a tuning constant and 9pi/256 is very
;; close to 0.11, we could just pick some appropriate L


;-  The End 


;;; Local Variables: 
;;; comment-end: ""
;;; comment-start: "; "
;;; mode: scheme
;;; outline-regexp: ";-+"
;;; comment-column: 0
;;; End:
