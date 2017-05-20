(define *scheme-version* "gambit")
(define *current-interpreter* (string->symbol *scheme-version*))
(define argv command-line)

(define currently-loading #f)
(define true #t)
(define false #f)
(define <uninitialised> '<uninitialised> )
(define <nameless> '<nameless> )

;; Registers to associate  classes, methods and objects with their name.

(define overdue-loans '())

(define original-display display)
(define fake-display (lambda x (void)))

(define original-newline newline)
(define fake-newline (lambda x (void)))

;(define original-ednl ednl)
;(define fake-ednl (lambda x (void)))

;(set! display fake-display)
;(set! newline fake-newline)
;(set! ednl fake-ednl)

(define warn <uninitialised>)
(define (warning-log #!rest args)
  (if (eqv? warn <uninitialised>)
		(set! warn (open-output-file "warning.log"))
		(display "Unable to open warning log\n"))
  (display args warn)
  (newline warn))


(define getenv (let ((ge getenv))
					  (lambda (var . rest)
						 (ge var))))

;; These may need changing from time to time!

;;?(if (not (getenv "SCHEME_LIBRARY_PATH")) (setenv "SCHEME_LIBRARY_PATH" "/usr/share/slib/"))
;;?(setenv "SCHEME_LIBRARY_PATH" "/usr/share/slib/")

(if (not (getenv "GAMBIT_IMPLEMENTATION_PATH")) (setenv "GAMBIT_IMPLEMENTATION_PATH" "/usr/share/gambit/"))
;;?(if (not (getenv "SLIB_IMPLEMENTATION_PATH")) (setenv "SLIB_IMPLEMENTATION_PATH" "/usr/share/slib/"))


;;; Smart load prevent us from accidentally loading a file twice.  This could pose problems if the
;;; file *needs* to be loaded more than once, but this can be dealt with by a forced load.


;; These provide a shotgun equality test which works with the classes and instances.
;; My goal is to make difficult bugs in subsequent work less likely.


;; (!filter selector lst) -- returns a list of those elements which fail the selector
(define (!filter selector lst)
  (filter (lambda x (not (apply selector x))) lst))


(define *primitive-load* load)

(define smart-load
  (let* ((oload load)
         (always-print-loading #f)
         (always-print-loaded #f)
         (always-load #f)
         (warn-loaded #t)
         (loaded '())
         (loading '())
			(EQ? eqv?)
			(MEMB memq)
         (prload (lambda (x y)
                   (display (string-append "\n[" x " "))
                   (display y)(display "]\n")))
         )
    (lambda (fn . args)
      (if (not (null? fn))
          (if (MEMB fn loaded)
              (if warn-loaded
                  (dnl "[" fn " is already loaded]"))
              (cond
               ;; ((and (string? fn) (not (null? args)))
               ;;  (dnl "forced loading of " fn)
               ;;  (oload fn) ;; forces a load, doesn't record it
               ;;  )

					;; Load the file irrespective of whether it has been loaded before
					((and (MEMB fn '(force force-load)) (not (null? args)))
					 (for-each oload args))

					;; The next two substantially change the behaviour ------
					((EQ? fn 'revert!)
					 (display "Reverted to original load\n")
					 (set! load oload))

               ((or (EQ? fn 'flush!)(EQ? fn 'flush))
					 (display "Flushed load list\n   ")
					 (display loaded)(newline)
                (set! loaded '())
					 )

					;; the next three return state information ---------------
					((EQ? fn 'loaded-list)
					 (reverse loaded))

					((EQ? fn 'loading-list)
					 loading)

               ((MEMB fn '(now-loading now-loading? current-file current-file?))
                ;;(prload "loaded" loaded)
					 (if (pair? loading) (car loading) #f)
					 )


               ((MEMB fn '(prloaded? loaded loaded-list loaded-list?))
                (prload "loaded" loaded))

               ((MEMB fn '(prloading? loaded loaded-list loaded-list?))
                (prload "loading" loading)
					 )

					;; Set/reset flags --------------------------------------
					((EQ? fn 'warn-loaded)
					 (display "Warning when files are already loaded\n")
                (set! warn-loaded #t))

					((EQ? fn '!warn-loaded)
					 (display "Not warning when files are already loaded\n")
					 (set! warn-loaded #f))

					;;--

               ((EQ? fn 'always-load)
					 (display "Always loading.\n")
                (set! always-load #t))

               ((EQ? fn '!always-load)
					 (display "Only loading new files.\n")
                (set! always-load #f))

					;;--

               ((EQ? fn 'print-loaded)
					 (display "Printing loaded files at each load.\n")
                (set! always-print-loaded #t))

               ((EQ? fn '!print-loaded)
					 (display "Not printing loaded files at each load.\n")
                (set! always-print-loaded #f))

					;;--

               ((EQ? fn 'print-loading)
					 (display "Printing currently loading files at each load.\n")
                (set! always-print-loading #t))

               ((EQ? fn '!print-loading)
					 (display "Not printing currently loading files at each load.\n")
                (set! always-print-loading #f))

					;; Print help -----------------------------------------------
					((EQ? fn 'help)
					 (display
					  (string-append
						"This load routine suppresses loading a file more than once "
						"by default.\n"
						"The load procedure responds to a number of symbols:\n\n"
						"help           this help message\n"
						"revert!        revert to the original load procedure\n"
						"flush!         flushes the list of loaded files\n"
						"list-loading   returns the list of active files\n"
						"now-loading?   returns the file currently being loaded\n"
						"loading\n"
						"list-loaded    returns the list of files already loaded\n"
						"loading?       prints the list of files that are currently "
						"loading\n"
						"loaded?        prints the list of loaded files\n"
						"warn-loaded    sets the flag that makes it warn about "
						"attempts to\n"
						"               load a file more that once\n"
						"!warn-loaded   turns off the warning\n"
						"always-load    (load...) will alway load the files "
						"indicated\n"
						"!alway-load    (load...) only loads files which have not been "
						"loaded\n"
						"print-loading  the list of loaded files is printed at each call "
						"to (load...)\n"
						"!print-loaded  turns off the previous flag\n"
						"print-loading  the list of loading files is printed at each call "
						"to (load...)\n"
						"!print-loading turns off the previous flag\n"
						"\n")))
               ((string? fn)
                (set! loading (cons fn loading))
                (if always-print-loading (prload "loading" loading))
                (if (or always-load (not (MEMB fn loaded)))
                    (begin
                      (oload fn)
                      (set! loading (cdr loading))
                      (set! loaded (cons fn loaded))
                      (if always-print-loaded (prload "loaded" loaded))))
                )
					(#t (error "bad argument to (load)" fn))
					)
              )
          )))
  )

(define load smart-load)



;; Makes gambit work with slib

;(include "/usr/lib/slib/gambit.init")

;--    Included files

;(require 'rev2-procedures)
;(require 'rev3-procedures)
;(require 'pretty-print)
;(require 'common-list-functions)

;(require 'repl)
;(require 'macro)
;(require 'macros-that-work)
;(repl:top-level macro:eval)

;(require 'stdio)
;(require 'sort)
;(require 'strcase)
;(require 'string-search)
;(require 'str)
;(require 'with-file)
;(require 'line-i/o)
;(require 'random)

(setenv "SCHEME_RC_LOADED" *scheme-version*)
;(setenv "SCHEME_LIBRARY_PATH" "/usr/share/slib/")

;; for C junkies :->
(define stdin 'use:current-input-port)
(define stdout 'use:current-output-port)
(define stderr 'use:current-error-port)


(define (maybe-expand-path path . dir)
  (if (string-index path #\~)
		(path-expand path)
		path))


(define (dnl* . args)
  (if (not (null? args))
      (let ((h (car args))
            (t (cdr args)))
        (display (car args))
        (for-each (lambda (x) (display " ") (display x)) t)))
  (newline))


(define (dnl . args)
  (if (not (null? args))
      (let ((h (car args))
            (t (cdr args)))
        (display (car args))
        (for-each (lambda (x) (display x)) t)))
  (newline))

(define ednl dnl)
(define ednl* dnl*)



;; This allows me to put in comments which I can "articulate" if needs be.
(define (Comment . args) #!void)

;; set the value associated with key in a-list
;; (assoc-set! list key value)

(define (list-copy l) ;; Remember, list-copy is the canonical list duplication routine
  (if (not (pair? l))
		l
		(cons (list-copy (car l)) (list-copy (cdr l)))))


;---- (!filter selector lst) -- returns a list of those elements which fail the selector

(define (filter selector lst)
  (if (pair? lst)
		(if (selector (car lst))
			 (cons (car lst) (filter selector (cdr lst)))
			 (filter selector (cdr lst)))
		lst))

(define (!filter selector lst)
  (filter (lambda x (not (apply selector x))) lst))

;; This is a list of data added by a (definition-comment ...) clause associated with a
;; (define...)
(define definition-comments '())

(define (definition-comment tag . comments)
  (set! definition-comments (append definition-comments (list (cons tag comments)))))

(define (describe item)
  (let* ((r (assq item definition-comments))
			(s (assq (cond
						 ((string? item) (string->symbol item))
						 ((symbol? item) (symbol->string item))
						 (#t '()))
						definition-comments)))
	 (cond
	  ((and r s)
		(display item)(display ":\n")
		(pp r)
		(pp s)
		(newline))
	  (r (display item)(display ":\n")
		  (pp r)
		  (newline))
	  (s (display item)(display ":\n")
		  (pp s)
		  (newline))
	  (#t (display "The indicated object, ")
			(write item)
			(display "does not have a comment recorded by (definition-comment ...)\n")))
	 ))

(define (symbol<? s t)
  (if (not (and (symbol? s) (symbol? t)))
		(error "Passed a non symbol to symbol<?" s t)
		(string<? (symbol->string s) (symbol->string t))))

(define (call-with-input-port p thunk)
  (let ((pp (current-input-port)))
	 (current-input-port p)
	 (thunk)
	 (current-input-port pp)))

(define (call-with-output-port p thunk)
  (let ((pp (current-output-port)))
	 (current-output-port p)
	 (thunk)
	 (current-output-port pp)))

(define (call-with-error-port p thunk)
  (let ((pp (current-error-port)))
	 (current-error-port p)
	 (thunk)
	 (current-error-port pp)))


;; ************* Examples using the next few functions follow after their definition. *************

;; The following functions expect the command to be an array of strings.
;; They work like any other port, really.

(define current-input-port
  (let ((cp current-input-port))
	 (lambda x
		(cond
		 ((> (length x) 1) 'too-many-arguments)
		 ((null? x) (cp))
		 (#t (set-current-input-port (car x)))))))

(define current-output-port
  (let ((cp current-output-port))
	 (lambda x
		(cond
		 ((> (length x) 1) 'too-many-arguments)
		 ((null? x) (cp))
		 (#t (set-current-output-port (car x)))))))


;#; ;; This is slower the subsequent version never leaves the interpreter's code
;#; (define (load-flat-list-from-file filename)
;#;   (reverse
;#;    (with-input-from-file filename
;#;      (lambda () 
;#;        (let loop ((new-entry (read)) (data '()))
;#; 	 (if (not (eof-object? new-entry))
;#; 	     (begin
;#; 	       (loop (read) (cons new-entry data)))
;#; 	     data))))))


(define (capture-string-from thunk)
  (let ((sp (open-output-string)))
    (call-with-output-port sp thunk)
    (let ((result (get-output-string sp)))
      (close-port sp) ;; **** chibi needs a close-port
      result)))

(define (load-lines-from-port f)
  (let loop ((line (read-line f))
				 (file '())
				 )
	 (if (eof-object? line)
		  file
		  (loop (read-line f) (append file (list line)))
		  )))


(define (capture-lines-from thunk)
  (let ((sp (open-output-string)))
    (call-with-output-port sp thunk)
    (let ((result (load-lines-from-port sp)))
      (close-port sp) ;; **** chibi needs a close-port
      result)))

(define (load-list-from-port f)
  (let loop ((line (read-line f))
				 (port '())
				 )
	 (if (not (eof-object? line))
		  (loop (read-line f) (append port (list (collapsing-strtok line " \t"))))
		  port)))


(define (capture-list-from thunk)
  (let ((sp (open-output-string)))
    (call-with-output-port sp thunk)
    (let ((result (load-list-from-port sp)))
      (close-port sp) ;; **** chibi needs a close-port
      result)))

(define (load-flat-list-from-port f)
  (let loop ((line (read-line f))
				 (port '())
				 )
	 (if (not (eof-object? line))
		  (loop (read-line f) (append port (collapsing-strtok line " \t")))
		  port)))

(define (capture-flat-list-from thunk)
  (let ((sp (open-output-string)))
    (call-with-output-port sp thunk)
    (let ((result (load-flat-list-from-port sp)))
      (close-port sp) ;; **** chibi needs a close-port
      result)))

; Hard to map to gambit
(define (load-list-from-pipe cmd-array . extras)
  (let ((cmd-array (if (string? cmd-array) (collapsing-strtok cmd-array " \t") cmd-array)))
	 (let* ((f (if (null? extras)
						(begin
						  (open-input-pipe cmd-array))
						(begin
						  (apply (lambda (x) (open-input-pipe cmd-array x) extras)))))
			  
			  (v (load-list-from-port f)))
		(close-port f)
		v)
	 ))

;; (define size+filename-list (load-list-from-pipe (list "ls" "-1s")))



;;(define (load-flat-list-from-pipe command . args)
;;  (let* ((f (apply open-input-pipe (cons command args)))
;;        (v (load-flat-list-from-port f)))
;;    (close-port f)
;;    v
;;    )
;;  )

(define (load-flat-list-from-pipe cmd-array . args)
  (let ((cmd-array (if (string? cmd-array) (collapsing-strtok cmd-array " \t") cmd-array)))
	 (let* ((f (apply (lambda () (open-input-pipe cmd-array)) args))
			  (v (load-flat-list-from-port f)))
		(close-port f)
		v
		)
	 ))

;;(define (load-list-from-command cmdline)
;;  (apply load-list-from-pipe (split-commandline cmdline)))

;;(define (load-flat-list-from-command cmdline)
;;  (apply load-flat-list-from-pipe (split-commandline cmdline)))


(define (load-list-from-file filename)
  (let ((f (open-input-file (maybe-expand-path filename))))
	 (let loop ((line (read-line f))
					(file '())
					)
		(if (not (eof-object? line))
			 (loop (read-line f) (append file (list line)))
			 file)))
  )

;; (define (load-list-from-file filename)
;;   (let* ((f (open-input-file (maybe-expand-path filename)))
;; 			(v (load-list-from-port f)))
;; 	 (close-port f)
;; 	 v))





(define (load-flat-list-from-file filename)
  (let ((f (open-input-file (maybe-expand-path filename))))
	 (let loop ((line (read-line f))
					(file '())
					)
		(if (not (eof-object? line))
			 (loop (read-line f) (append file (collapsing-strtok line " \t")))
			 file))))


(define (load-lines-from-file filename)
  (let ((f (open-input-file (maybe-expand-path filename))))
	 (let loop ((line (read-line f))
					(file '())
					)
		(if (eof-object? line)
			 file
			 (loop (read-line f) (append file (list line)))
			 ))))

(define (load-lists-from-file filename separator)
  (map (lambda (x) (strtok x separator)) (load-lines-from-file filename)))


;  (define (load-list-from-file filename)
;    (with-input-from-pipe (string-append "echo '('; cat " filename "; echo ')'")
;				  (lambda () 
;				    (read))))

;(define (read-array-from-file fname . bounds)
;  (let ((f (open-file (maybe-expand-path fname) "r"))
;		  (a (apply make-uniform-array (append (list 0.0) bounds)))
;		  )
;	 (serial-array-map! a (lambda (x) (read f)) a)
;	 (close-port f)
;	 a))