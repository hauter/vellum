(in-package #:cl-data-frames.header)


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


(declaim (inline decorate))
(defun decorate (range &key list-format (header (header)))
  (check-type list-format (member nil :pair))
  (decorate-data header range :list-format list-format))


(declaim (inline rr))
(defun rr (index &optional (row (row)))
  (row-at (header) row index))


(declaim (inline (setf rr)))
(defun (setf rr) (new-value index &optional (row (row)))
  (setf (row-at (header) row index) new-value))


(declaim (inline nullify))
(defun nullify (&optional (row (row)))
  (iterate
    (with header = (header))
    (for i from 0 below (column-count header))
    (setf (row-at header row i) :null)))
