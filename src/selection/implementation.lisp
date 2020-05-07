(cl:in-package #:vellum.selection)

(defclass stack-frame ()
  ((%state :initarg :state
           :accessor access-state)
   (%current-block :initarg :current-block
                   :reader read-current-block)
   (%index :initarg :index
           :accessor access-index)
   (%value :initarg :value
           :accessor access-value)
   (%previous-frame :initarg :previous-frame
                    :reader read-previous-frame))
  (:default-initargs :index (list -1)
                     :state nil
                     :value nil
                     :previous-frame nil))


(defclass selection ()
  ((%stack :initarg :stack
           :accessor access-stack)))


(defun index (stack-frame)
  (car (access-index stack-frame)))


(defun (setf index) (new-value stack-frame)
  (setf (car (access-index stack-frame)) new-value))


(defgeneric new-stack-frame (previous-stack-frame current-block))


(defmethod new-stack-frame (previous-stack-frame (current-block fundamental-selection-block))
  (make 'stack-frame
        :index (access-index previous-stack-frame)
        :previous-frame previous-stack-frame
        :current-block current-block
        :state nil))


(defmethod new-stack-frame (previous-stack-frame (current-block bracket-selection-block))
  (make 'stack-frame
        :index (access-index previous-stack-frame)
        :previous-frame previous-stack-frame
        :current-block current-block
        :state (read-children current-block)))


(defmethod new-stack-frame (previous-stack-frame (current-block root-selection-block))
  (make 'stack-frame
        :index (list -1)
        :previous-frame previous-stack-frame
        :current-block current-block
        :state (read-children current-block)))


(defgeneric forward* (current-block stack-frame))


(defgeneric overlaps (current-block stack-frame))


(defun forward (stack-frame)
  (forward* (read-current-block stack-frame)
            stack-frame))


(defun next-position (selection)
  (iterate
    (setf #1=(access-stack selection) (forward #1#))
    (for stack-frame = #1#)
    (until (null stack-frame))
    (for value = (access-value stack-frame))
    (cond ((null stack-frame)
           (leave nil))
          ((null value)
           (next-iteration))
          (t (leave value)))))


(defclass fundamental-selection-block ()
  ((%parent :initarg :parent
            :accessor access-parent)))


(defclass bracket-selection-block (fundamental-selection-block)
  ((%children :initarg :children
              :type list
              :reader read-children)))


(defclass root-selection-block (bracket-selection-block)
  ())


(defmethod print-object ((object bracket-selection-block) stream)
  (print-unreadable-object (object stream :type t)
    (format stream "~{~a~^ ~}" (read-children object))))


(defclass bounded-selection-block (bracket-selection-block)
  ((%from :initarg :from
          :reader read-from)
   (%to :initarg :to
        :reader read-to))
  (:default-initargs :from 0
                     :to nil))


(defun ensure-index (alias-or-index)
  (handler-case
      (if (integerp alias-or-index)
          alias-or-index
          (vellum.header:alias-to-index (vellum.header:header)
                                        alias-or-index))
    (vellum.header:no-header (e)
      (declare (ignore e))
      (error 'alias-when-selecting-row
             :value alias-or-index
             :format-control "Attempting to access row by a non-integer value: ~a"
             :format-arguments `(,alias-or-index)))))


(defmethod shared-initialize :after ((object bounded-selection-block)
                                     slots
                                     &rest arguments)
  (declare (ignore slots arguments))
  (let ((from (read-from object))
        (to (read-to object)))
    (setf (slot-value object '%to)
          (if (null to)
              most-positive-fixnum
              (ensure-index to)))
    (setf (slot-value object '%from) (ensure-index from))))


(defclass skip-selection-block (bounded-selection-block)
  ((%from :initarg :skip-from)
   (%to :initarg :skip-to)))


(defclass take-selection-block (bounded-selection-block)
  ((%from :initarg :take-from)
   (%to :initarg :take-to)))


(defclass value-selection-block (fundamental-selection-block)
  ((%value :initarg :value
           :reader read-value)))


(defmethod shared-initialize :after ((object value-selection-block)
                                     slots
                                     &rest arguments)
  (declare (ignore slots arguments))
  (setf (slot-value object '%value)
        (ensure-index (read-value object))))


(defmethod print-object ((block value-selection-block) stream)
  (print-unreadable-object (block stream :type t)
    (format stream "~a" (read-value block))))


(defgeneric make-selection-block* (symbol form))


(defun first-atom (form)
  (if (atom form)
      form
      (first-atom (first form))))


(defun make-selection-block (form)
  (let ((symbol (first-atom form)))
    (make-selection-block* symbol form)))


(defun group-selection-input (input)
  (batches input 2))


(define-constant +bracket-forms+
    '((:take-from :skip-from)
      (:take-to :skip-to)
      (take-selection-block skip-selection-block))
  :test 'equal)


(defun openings ()
  (first +bracket-forms+))


(defun closings ()
  (second +bracket-forms+))


(defun block-classes ()
  (third +bracket-forms+))


(defun opening-p (symbol)
  (member symbol (openings)))


(defun closing-p (symbol)
  (member symbol (closings)))


(defun matching-opening-p (closing symbol)
  (eql (position symbol (openings))
       (position closing (closings))))


(defun matching-block-class (symbol)
  (or (when-let ((position (position symbol (openings))))
        (elt (block-classes) position))
      (when-let ((position (position symbol (closings))))
        (elt (block-classes) position))))


(defun matching-closing-p (opening symbol)
  (let ((opening-position (position opening (openings)))
        (closing-position (position symbol (closings))))
    (and opening-position closing-position
         (eql opening-position closing-position))))


(defun matching-opening (closing)
  (elt (openings) (position closing (closings))))


(defmethod make-selection-block* (symbol form)
  (bind (((arguments children) form)
         (result
          (apply #'make (matching-block-class symbol)
                 :parent nil
                 :children children
                 arguments)))
    (iterate
      (for child in children)
      (setf (access-parent child) result))
    result))


(defmethod make-selection-block* ((symbol (eql :v)) form)
  (make 'value-selection-block
        :value (second form)))


(defun fold-selection-input (input)
  (bind ((batches (batches input 2))
         ((:labels fold (opening list))
          (iterate
            (with result = '())
            (until (endp list))
            (for (label value) = (first list))
            (cond ((opening-p label)
                   (bind (((:values tree rest)
                           (fold (first list) (rest list))))
                     (push tree result)
                     (setf list rest)
                     (next-iteration)))
                  ((matching-closing-p (first opening) label)
                   (leave (values (make-selection-block
                                   (list (append opening
                                                 (first list))
                                         (reverse result)))
                                  (rest list))))
                  ((closing-p label)
                   (leave (values (make-selection-block
                                   (list (first list)
                                         (reverse result)))
                                  (rest list))))
                  (t (push (make-selection-block (first list))
                           result)
                     (pop list)))
            (finally (return (values (reverse result)
                                     '())))))
         (folding-result (fold nil batches))
         (top-level (if (listp folding-result)
                        folding-result
                        (list folding-result)))
         (root (make 'root-selection-block :children top-level
                                           :parent nil)))
    (iterate
      (for elt in top-level)
      (setf (access-parent elt) root))
    (make 'selection :stack (new-stack-frame nil root))))


(defmethod overlaps ((current-block bounded-selection-block)
                     stack-frame)
  (>= (1+ (index stack-frame))
      (read-from current-block)))


(defmethod overlaps ((current-block value-selection-block)
                     stack-frame)
  t)


(defmethod forward* ((current-block take-selection-block)
                     stack-frame)
  (let ((index (index stack-frame))
        (from (read-from current-block))
        (to (read-to current-block))
        (state (access-state stack-frame)))
    (cond ((>= index to)
           (forward (read-previous-frame stack-frame)))
          ((< index from)
           (setf (index stack-frame) from
                 (access-value stack-frame) from)
           stack-frame)
          ((and (not (endp state))
                (overlaps (first state)
                          stack-frame))
           (forward (new-stack-frame stack-frame
                                     (pop (access-state stack-frame)))))
          (t (let ((new-index (1+ (index stack-frame))))
               (setf (index stack-frame) new-index
                     (access-value stack-frame) new-index)
               stack-frame)))))


(defun rootp (block)
  (typep block 'root-selection-block))


(defmethod forward* ((current-block skip-selection-block)
                     stack-frame)
  (let* ((index (index stack-frame))
         (from (read-from current-block))
         (to (read-to current-block))
         (state (access-state stack-frame))
         (previous-stack-frame (read-previous-frame stack-frame))
         (parent (access-parent current-block))
         (previous-state (access-state previous-stack-frame)))
    (cond ((or (< (1+ index) from)
                (and (endp previous-state)
                     (rootp parent)
                     (>= index to)))
           (setf (access-value stack-frame)
                 (incf (index stack-frame)))
            stack-frame)
           ((>= index to)
            (forward (read-previous-frame stack-frame)))
          ((and (not (endp state))
                (overlaps (first state)
                          stack-frame))
           (forward (new-stack-frame stack-frame
                                     (pop (access-state stack-frame)))))
          (t (setf (access-value stack-frame) nil)
             (incf (index stack-frame))
             stack-frame))))


(defmethod forward* ((current-block value-selection-block)
                     stack-frame)
  (if (access-state stack-frame)
      (forward (read-previous-frame stack-frame))
      (progn
        (setf (access-value stack-frame) (read-value current-block)
              (access-state stack-frame) t)
        stack-frame)))


(defmethod forward* ((current-block root-selection-block)
                     stack-frame)
  (let ((state (access-state stack-frame)))
    (if (endp state)
        nil
        (forward (new-stack-frame stack-frame
                                  (pop (access-state stack-frame)))))))