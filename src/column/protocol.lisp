(in-package #:cl-df.column)


(defgeneric column-type (column))
(defgeneric column-size (column))
(defgeneric column-at (column index))
(defgeneric (setf column-at) (new-value column index))
;; (defgeneric install-change-observer (column observer))
;; (defgeneric change-observer-obsolete-p (observer))
;; (defgeneric notify-change (observer index new-value))
;; (defgeneric clear-change-observers (column))
;; (defgeneric run-change-observers (column index new-value))
(defgeneric make-iterator (column))

(defgeneric iterator-at (iterator column))
(defgeneric (setf iterator-at) (new-value iterator column))
(defgeneric move-iterator (iterator times))
(defgeneric augment-iterator (iterator column))
(defgeneric finish-iterator (iterator))
(defgeneric remove-nulls (iterator))
(defgeneric truncate-to-length (column length))
(defgeneric index (iterator))
