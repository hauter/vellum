(cl:in-package #:cl-df.csv)


(defgeneric to-stream (object stream))

(defgeneric from-string (type string))