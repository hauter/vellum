(cl:in-package #:vellum.header)


(declaim (inline validate-active-row))
(defun validate-active-row ()
  (when (null *row*)
    (error 'no-row)))


(declaim (inline validate-active-header))
(defun validate-active-header ()
  (when (null *header*)
    (error 'no-header)))


(declaim (inline set-row))
(defun set-row (row)
  (validate-active-row)
  (setf (unbox *row*) row))


(declaim (inline row))
(defun row ()
  (validate-active-row)
  (unbox *row*))


(declaim (inline header))
(defun header ()
  (validate-active-header)
  *header*)


(declaim (inline rr))
(defun rr (index &optional (row (row)) (header (header)))
  (row-at header row index))


(declaim (inline (setf rr)))
(defun (setf rr) (new-value index &optional (row (row)) (header (header)))
  (setf (row-at header row index) new-value))


(defun current-row-as-vector (&optional (header (header)) (row (row)))
  (iterate
    (with column-count = (column-count header))
    (with result = (make-array column-count))
    (for i from 0 below column-count)
    (setf (aref result i) (rr i row))
    (finally (return result))))


(defun make-bind-row (optimized-closure non-optimized-closure)
  (lret ((result (make 'bind-row :optimized-closure optimized-closure)))
    (c2mop:set-funcallable-instance-function result non-optimized-closure)))


(defun ensure-index (header index/name)
  (check-type index/name (or symbol string non-negative-integer))
  (if (numberp index/name)
      (let ((column-count (column-count header)))
        (unless (< index/name column-count)
          (error 'no-column
                 :bounds `(< 0 ,column-count)
                 :argument 'index/name
                 :value index/name
                 :format-arguments (list index/name)))
        index/name)
      (vellum.header:name-to-index header
                                   index/name)))


(defun read-new-value ()
  (format t "Enter a new value: ")
  (multiple-value-list (eval (read))))


(defun column-names (header)
  (~>> header
       vellum.header:column-specs
       (mapcar (lambda (x) (getf x :name)))))


(declaim (inline setf-predicate-check))
(defun setf-predicate-check (new-value header column)
  (tagbody main
     (block nil
       (restart-case (check-predicate header column new-value)
         (keep-old-value ()
           :report "Skip assigning the new value."
           (return (values nil nil)))
         (set-to-null ()
           :report "Set the row position to :null."
           (setf new-value :null)
           (go main))
         (provide-new-value (v)
           :report "Enter the new value."
           :interactive read-new-value
           (setf new-value v)
           (go main)))))
  (values new-value t))
