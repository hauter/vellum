(cl:in-package #:cl-user)


(defpackage #:vellum.selection
  (:use #:cl #:vellum.aux-package)
  (:export
   #:fold-selection-input
   #:alias-when-selecting-row
   #:next-position))
