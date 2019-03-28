(in-package #:cl-df.table)

(prove:plan 24)

(defparameter *test-data* #(#(1 a 5 s)
                            #(2 b 6 s)
                            #(3 c 7 s)))


(cl-df:with-header ((cl-df:make-header 'cl-df:standard-header
                                       nil nil nil nil))
  (defparameter *table*
    (~> *test-data*
        cl-ds:whole-range
        cl-df:decorate
        cl-df:to-table)))

(prove:is (cl-df:at *table* 0 0) 1)
(prove:is (cl-df:at *table* 0 1) 2)
(prove:is (cl-df:at *table* 0 2) 3)

(prove:is (cl-df:at *table* 1 0) 'a)
(prove:is (cl-df:at *table* 1 1) 'b)
(prove:is (cl-df:at *table* 1 2) 'c)

(prove:is (cl-df:at *table* 2 0) 5)
(prove:is (cl-df:at *table* 2 1) 6)
(prove:is (cl-df:at *table* 2 2) 7)

(prove:is (cl-df:at *table* 3 0) 's)
(prove:is (cl-df:at *table* 3 1) 's)
(prove:is (cl-df:at *table* 3 2) 's)

(defparameter *replica*
  (cl-df:transform *table*
                   (cl-df:body (setf (cl-df:rr 0) (+ 1 (cl-df:rr 0))))
                   :in-place nil))

(prove:is (cl-df:at *table* 0 0) 1)
(prove:is (cl-df:at *table* 0 1) 2)
(prove:is (cl-df:at *table* 0 2) 3)

(prove:is (cl-df:at *replica* 0 0) 2)
(prove:is (cl-df:at *replica* 0 1) 3)
(prove:is (cl-df:at *replica* 0 2) 4)

(cl-df:transform *table*
                 (cl-df:body (setf (cl-df:rr 0) (* 2 (cl-df:rr 0))))
                 :in-place t)

(prove:is (cl-df:at *table* 0 0) 2)
(prove:is (cl-df:at *table* 0 1) 4)
(prove:is (cl-df:at *table* 0 2) 6)

(prove:is (cl-df:at *replica* 0 0) 2)
(prove:is (cl-df:at *replica* 0 1) 3)
(prove:is (cl-df:at *replica* 0 2) 4)

(prove:finalize)