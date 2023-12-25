(cl:in-package #:vellum.table)

(declaim (inline row-at))
(defun row-at (header row name)
  (let ((column (if (integerp name)
                    name
                    (vellum.header:name-to-index header name))))
    (declare (type integer column))
    (etypecase row
      (table-row
       (let ((iterator (table-row-iterator row)))
         (vellum.column:iterator-at iterator column)))
      (simple-vector
       (let ((length (length row)))
         (declare (type fixnum length))
         (unless (< -1 column length)
           (error 'vellum.header:no-column
                  :bounds `(0 ,length)
                  :argument 'column
                  :value column
                  :format-arguments (list column)))
         (locally (declare (optimize (speed 3) (safety 0)
                                     (space 0) (debug 0)))
           (aref row column))))
      (sequence
       (let ((length (length row)))
         (unless (< -1 column length)
           (error 'vellum.header:no-column
                   :bounds (iota length)
                   :argument 'column
                   :value column
                   :format-arguments (list column)))
         (elt row column))))))


(declaim (inline (setf row-at)))
(defun (setf row-at) (new-value header row name)
  (let ((column (if (integerp name)
                    name
                    (vellum.header:name-to-index header name))))
    (declare (type integer column))
    (etypecase row
      (setfable-table-row
       (setf (~> row setfable-table-row-iterator (vellum.column:iterator-at column))
             new-value))
      (simple-vector
        (let ((length (length row)))
          (declare (type fixnum length))
          (unless (< -1 column length)
            (error 'vellum.header:no-column
                   :bounds `(0 ,length)
                   :argument 'column
                   :value column
                   :format-arguments (list column)))
          (locally (declare (optimize (speed 3) (safety 0)
                                      (space 0) (debug 0)))
            (setf (aref row column) new-value))))
      (sequence
       (let ((length (length row)))
         (unless (< -1 column length)
           (error 'vellum.header:no-column
                   :bounds (iota length)
                   :argument 'column
                   :value column
                   :format-arguments (list column)))
         (setf (elt row column) new-value))))))


(declaim (inline rr))
(defun rr (index
           &optional (row (vellum.header:row)) (header (vellum.header:header)))
  (row-at header row index))


(declaim (inline (setf rr)))
(defun (setf rr) (new-value index
                  &optional (row (vellum.header:row)) (header (vellum.header:header)))
  (setf (row-at header row index) new-value))


(defun finish-transformation ()
  (funcall *transform-control* :finish))


(defun nullify ()
  (funcall *transform-control* :nullify))


(defun drop-row (&optional error)
  (if (null error)
      (funcall *transform-control* :drop)
      (invoke-restart 'drop-row)))


(defun make-table (&key
                     (class 'standard-table)
                     (columns '() columns-p)
                     (header (if columns-p
                                 (apply #'vellum.header:make-header
                                        columns)
                                 (vellum.header:header))))
  (make-table* class header))


(defun hstack (frames &key (isolate t))
  (let ((list (if (listp frames)
                  frames
                  (cl-ds.alg:to-list frames))))
    (hstack* (first list) (rest list)
             :isolate isolate)))


(defun vstack (frames)
  (let ((list (if (listp frames)
                  frames
                  (cl-ds.alg:to-list frames))))
    (vstack* (first list) (rest list))))


(defun row-to-list (&rest forms)
  (let* ((header (vellum.header:header))
         (selection
           (if (endp forms)
               (iota (vellum.header:column-count header))
               (~> (apply #'vellum.selection:s forms)
                   (vellum.selection:address-range
                    (lambda (x) (vellum.header:ensure-index header x))
                    (vellum.header:column-count header))
                   cl-ds.alg:to-list))))
    (lambda (&rest ignored)
      (declare (ignore ignored))
      (mapcar #'rr selection))))


(defun row-to-vector (&rest forms)
  (let* ((header (vellum.header:header))
         (selection
           (if (endp forms)
               (iota (vellum.header:column-count header))
               (~> (apply #'vellum.selection:s forms)
                   (vellum.selection:address-range
                    (lambda (x) (vellum.header:ensure-index header x))
                    (vellum.header:column-count header))
                   cl-ds.alg:to-list))))
    (lambda (&rest ignored)
      (declare (ignore ignored))
      (map 'vector #'rr selection))))


(defun column-names (table)
  (~> table vellum.table:header vellum.header:column-names))


(defun current-row-as-vector (&optional
                                (header (vellum.header:header))
                                (row (vellum.header:row)))
  (iterate
    (with column-count = (vellum.header:column-count header))
    (with result = (make-array column-count))
    (for i from 0 below column-count)
    (setf (aref result i) (rr i row))
    (finally (return result))))


(defun vs (&rest forms)
  (let ((header (vellum.header:header)))
    (~> (apply #'vellum.selection:s forms)
        (vellum.selection:address-range
         (lambda (x) (vellum.header:ensure-index header x))
         (vellum.header:column-count header))
        (cl-ds.alg:on-each (lambda (x) (rr x))))))


(defun make-bind-row (optimized-closure non-optimized-closure)
  (lret ((result (make 'bind-row :optimized-closure optimized-closure)))
    (c2mop:set-funcallable-instance-function result non-optimized-closure)))


(cl-ds.alg.meta:define-aggregation-function
    to-table to-table-function

    (:range &key body key class columns header enable-restarts wrap-errors after)

    (:range &key
     (key #'identity)
     (after #'identity)
     (body nil)
     (class 'standard-table)
     (enable-restarts *enable-restarts*)
     (wrap-errors *wrap-errors*)
     (columns '())
     (header (apply #'vellum.header:make-header columns)))

    (%function %transformation %done %after)

    ((setf %function (bind-row-closure
                      body :header header)
           %done nil
           %transformation (~> (table-from-header class header)
                               (transformation nil :in-place t
                                                   :enable-restarts enable-restarts
                                                   :wrap-errors wrap-errors))))

    ((row)
     (unless %done
       (block main
         (let ((transform-control (lambda (operation)
                                      (cond ((eq operation :finish)
                                             (setf %done t)
                                             (return-from main))
                                            ((eq operation :drop)
                                             (iterate
                                               (for i from 0 below (length row))
                                               (setf (rr i) :null))
                                             (return-from main))
                                            (t nil)))))
           (transform-row %transformation
                          (lambda (&rest all) (declare (ignore all))
                            (iterate
                              (for i from 0 below (length row))
                              (for value = (elt row i))
                              (setf (rr i) value))
                            (let ((*transform-control* transform-control))
                              (funcall %function (standard-transformation-row %transformation)))))))))

    ((transformation-result %transformation)))


(defun run-in-jupyter-p ()
  (and (string= "JUPYTER" (package-name (symbol-package (type-of *standard-output*))))
       (string= "IOPUB-STREAM" (symbol-name (type-of *standard-output*)))))

(defun hash-tables-columns (dict-list)
  "Get all columns from hash-tabls"
  (loop with result = nil for d in dict-list
        do (loop for key in (hash-table-keys d)
                 do (pushnew key result :test #'string=))
        finally (return result)))

(defun hash-table-values-range (dict-list keys)
  (loop with result = nil for d in dict-list
        collect (hash-table-values-by-keys d keys)))

(defun hash-table-values-by-keys (dict keys)
  (loop for key in keys
        collect (serapeum:@ dict key)))
