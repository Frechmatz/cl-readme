(in-package :cl-readme)

(defparameter *home-directory* nil "Home directory of the current project.")
(defparameter *tab-width* 4 "Width of a tab. Used, when tabs are to be replaced with space characters.")

(defun validate-home-directory ()
  (if (not *home-directory*)
      (error "Variable *HOME-DIRECTORY* not set")))

(defun lambda-list-arg-to-string (arg)
  (cond
    ((keywordp arg)
     (format nil ":~a" arg))
    ((symbolp arg)
     (symbol-name arg))
    ((stringp arg)
     (format nil "\"~a\"" arg))
    ((listp arg)
     (concatenate 'string
		  "("
		  (reduce
		   (lambda(buffer item)
		     (concatenate 'string buffer
				  (if (> (length buffer) 0) " " "")
				  (lambda-list-arg-to-string item)))
		   arg
		   :initial-value "")
		  ")"))
    (t (format nil "~a" arg))))

;; uses sbcl extensions
(defun sbcl-make-function-decl (f)
  "Creates a function declaration string using SBCL specific functionality."
  (let ((f-name (symbol-name f))
	(f-lambda-list-str
	 (mapcar
	  (lambda (item) (lambda-list-arg-to-string item))
	  (sb-introspect:function-lambda-list f))))
    (let ((ll (reduce
	       (lambda(buffer item) (concatenate 'string buffer item " "))
	       f-lambda-list-str
	       :initial-value "")))
      (concatenate 'string
		   "<b>"
		   (string-downcase (package-name (symbol-package f)))
		   ":"
		   (string-downcase f-name)
		   "</b>"
		   " "
		   (string-downcase ll)))))

(defun current-date ()
  "Returns a string representing the current date and time."
  (multiple-value-bind (sec min hr day mon yr dow dst-p tz)
      (get-decoded-time)
    (declare (ignore dow dst-p tz))
    ;; 2018-09-19 21:28:16
    (let ((str (format nil "~4,'0d-~2,'0d-~2,'0d  ~2,'0d:~2,'0d:~2,'0d" yr mon day hr min sec)))
      str)))

(defun make-path (path)
  "Creates a path relative to *home-directory*. The function has the following arguments:
   <ul>
      <li>path The path, e.g. examples/example-1.lisp.</li>
   </ul>"
  (validate-home-directory)
  (concatenate 'string *home-directory* path))

(defun format-string (str &key replace-tabs escape)
  (let ((tab-string (make-sequence 'string *tab-width* :initial-element #\Space)))
    (let ((string-stream (make-string-output-stream)))
      (dotimes (i (length str))
	(let ((ch (elt str i)))
	  (cond
	    ((and replace-tabs (eql ch #\Tab))
	     (write-string tab-string string-stream))
	    ((and escape (eql ch #\<))
	     (write-string "&lt;" string-stream))
	    ((and escape (eql ch #\>))
	     (write-string "&gt;" string-stream))
	    ((and escape (eql ch #\&))
	     (write-string "&amp;" string-stream))
	    (t (write-char ch string-stream)))))
      (get-output-stream-string string-stream))))

(defun read-file (path &key (replace-tabs nil) (escape nil))
  (let ((output (make-array '(0) :element-type 'base-char
			    :fill-pointer 0 :adjustable t)))
    (with-output-to-string (s output)
      (with-open-file (fh (make-path path) :direction :input :external-format :utf-8)
	(loop 
	   (let ((str (read-line fh nil)))
	     (if (not str)
		 (return)
		 (format s "~a~%" (format-string str :replace-tabs replace-tabs :escape escape)))))))
    (string-trim '(#\Space #\Tab #\Newline) output)))

(defun read-verbatim (path &key (replace-tabs nil))
  "Reads a file and returns it as a string. Does not add any styling. This function
   is typically used to insert plain HTML files into the documentation.
   The function has the following arguments:
   <ul>
      <li>path Path of the file relative to *home-directory*.</li>
      <li>:replace-tabs If t then tabs are replaced with spaces according to the *tab-width* variable.</li>
   </ul>"
  (read-file path :replace-tabs replace-tabs :escape nil))

(defun read-code (path)
  "Returns the HTML representation of code denoted by a path. Tabs are replaced by 
   spaces according to the *tab-width* variable. The function has the following arguments:
   <ul>
      <li>path Path of the file relative to *home-directory*.</li>
   </ul>"
  (concatenate 'string
	       "<p><pre><code>"
	       (read-file path :replace-tabs t :escape t)
	       "</code></pre></p>"))
