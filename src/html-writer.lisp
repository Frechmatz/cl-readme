(in-package :cl-html-readme)

;;
;; Transformation functions
;;

(defun set-heading-ids (doc)
  "Assign ids to toc-headings. Returns a new documentation tree."
  (let ((id-store nil) (tree-builder (make-instance 'cl-html-readme-dsl:tree-builder)))
    (labels ((make-id (name &key (counter 0))
	       (let ((id (if (eq 0 counter) name (format nil "~a-~a" name counter))))
		 (if (find id id-store :test #'string=)
		     (make-id name :counter (+ 1 counter))
		     (progn
		       (push id id-store)
		       id))))
	     (set-id (properties)
	       (let ((l (copy-list properties)))
		 (setf (getf l :id) (make-id (getf l :name)))
		 l)))
      (cl-html-readme-dsl:walk-tree
       doc
       :open-element
       (lambda(element-symbol element-properties content)
	 (declare (ignore content))
	 (if (getf element-properties :toc)
	     (cl-html-readme-dsl:open-element tree-builder element-symbol (set-id element-properties))
	     (cl-html-readme-dsl:open-element tree-builder element-symbol element-properties))
	 nil)
       :close-element
       (lambda(context) (declare (ignore context)) (cl-html-readme-dsl:close-element tree-builder))
       :text
       (lambda(str) (cl-html-readme-dsl:add-text tree-builder str)))
      (cl-html-readme-dsl:get-tree tree-builder))))

(defun set-toc (doc)
  "Replace toc element with toc-root. Returns a new documentation tree."
  (let ((tree-builder (make-instance 'cl-html-readme-dsl:tree-builder)))
    (cl-html-readme-dsl:walk-tree
     doc
     :open-element
     (lambda(element-symbol element-properties content)
       (declare (ignore content))
       (if (cl-html-readme-dsl:toc-p element-symbol)
	   (progn
	     (cl-html-readme-dsl:extract-toc doc tree-builder)
	     :ignore-close-element)
	   (progn
	     (cl-html-readme-dsl:open-element tree-builder element-symbol element-properties)
	     t)))
       :close-element
       (lambda(context)
	 (if (not (eq context :ignore-close-element))
	     (cl-html-readme-dsl:close-element tree-builder)))
       :text
       (lambda(str) (cl-html-readme-dsl:add-text tree-builder str)))
    (cl-html-readme-dsl:get-tree tree-builder)))

(defun set-heading-indentation-levels (doc)
  "Set indentation levels of heading elements. Returns a new documentation tree."
  (let ((level 0) (tree-builder (make-instance 'cl-html-readme-dsl:tree-builder)))
    (labels ((set-indentation-level (properties)
	       (let ((l (copy-list properties)))
		 (setf (getf l :level) level)
		 l)))
      (cl-html-readme-dsl:walk-tree
       doc
       :open-element
       (lambda(element-symbol element-properties content)
	 (declare (ignore content))
	 (if (cl-html-readme-dsl:heading-p element-symbol)
	     (progn
	       (cl-html-readme-dsl:open-element
		tree-builder element-symbol
		(set-indentation-level element-properties))
	       (setf level (+ 1 level))
	       :decrement-level)
	     (progn
	       (cl-html-readme-dsl:open-element tree-builder element-symbol element-properties)
	       nil)))
       :close-element
       (lambda(context)
	 (if (eq context :decrement-level)
	     (setf level (+ -1 level)))
	 (cl-html-readme-dsl:close-element tree-builder))
       :text
       (lambda(str) (cl-html-readme-dsl:add-text tree-builder str)))
      (cl-html-readme-dsl:get-tree tree-builder))))

;;
;; HTML generation
;;

(defun serialize (output-stream doc)
  (labels ((newline ()
	     (princ #\Newline output-stream))
	   (format-class (class)
	     (if class (format nil " class=\"~a\"" class) ""))
	   (format-style (style)
	     (if style (format nil " style=\"~a\"" style) ""))
	   (format-id (properties)
	     (if (getf properties :id)
		 (format nil " id=\"~a\"" (getf properties :id)) ""))
	   (format-heading (properties)
	     (let ((level (getf properties :level)))
	       (if (<= level 5)
		   (format nil "h~a" (+ 1 level))
		   (format nil "h6")))))
    (cl-html-readme-dsl:walk-tree
     doc
     :open-element
     (lambda(element-symbol element-properties content)
       (declare (ignore content))
       (cond
	 ((cl-html-readme-dsl:heading-p element-symbol)
	  ;; <h{level} id={id} class={class} style={style}> {name} </h{level}>
	  (newline)
	  (format
	   output-stream
	   "<~a~a~a~a>~a</~a>"
	   (format-heading element-properties)
	   (format-id element-properties)
	   (format-class (getf element-properties :class))
	   (format-style (getf element-properties :style))
	   (getf element-properties :name)
	   (format-heading element-properties))
	  nil)
	 ((cl-html-readme-dsl:semantic-p element-symbol)
	  (newline)
	  ;; <{name} class={class} style={style}>...</{name}>
	  (format
	   output-stream
	   "<~a~a~a>"
	   (getf element-properties :name)
	   (format-class (getf element-properties :class))
	   (format-style (getf element-properties :style)))
	  (format nil "</~a>" (getf element-properties :name)))
	 ((cl-html-readme-dsl:toc-root-p element-symbol)
	  (newline)
	  ;; <ul class={class} style={style}>...</ul>
	  (format
	   output-stream
	   "<ul~a~a>"
	   (format-class (getf element-properties :class))
	   (format-style (getf element-properties :style)))
	  "</ul>")
	 ((cl-html-readme-dsl:toc-item-p element-symbol)
	  ;; <li class={toc-class} style={toc-style}> <a href=#{id}> {name} </a> </li>
	  (newline)
	  (format
	   output-stream
	   "<li~a~a><a href=\"#~a\">~a</a></li>"
	   (format-class (getf element-properties :class))
	   (format-style (getf element-properties :style))
	   (getf element-properties :id)
	   (getf element-properties :name))
	  nil)
	 ((cl-html-readme-dsl:toc-container-p element-symbol)
	  ;; <li class={item-class} style={item-style}> <a href=#{id}> {name} </a>
	  ;; <ul class={class} style={style}>...</ul>
	  ;; </li>
	  (newline)
	  (format
	   output-stream
	   "<li~a~a><a href=\"#~a\">~a</a><ul~a~a>"
	   (format-class (getf element-properties :class))
	   (format-style (getf element-properties :style))
	   (getf element-properties :id)
	   (getf element-properties :name)
	   (format-class (getf element-properties :container-class))
	   (format-style (getf element-properties :container-style)))
	  "</ul></li>")
	 (t (error (format nil "Dont know how to serialize ~a" element-symbol)))))
     :close-element
     (lambda(context)
       (if context
	   (format output-stream "~a" context)))
     :text
     (lambda(str)
       (format output-stream "~a" str)))
    nil))

;;
;; API
;;

(defun doc-to-html (output-stream documentation)
  "Serializes a documentation object to HTML. The function has the following parameters:
   <ul>
       <li>output-stream A stream into which the resulting HTML is written.</li>
       <li>documentation A list following the syntax of the DSL.</li>
   </ul>"
  (setf documentation (set-heading-ids documentation))
  (setf documentation (set-toc documentation))
  (setf documentation (set-heading-indentation-levels documentation))
  (serialize output-stream documentation)
  nil)
