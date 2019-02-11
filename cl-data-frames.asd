(in-package #:cl-user)


(asdf:defsystem cl-data-frames
  :name "cl-data-frames"
  :version "0.0.0"
  :license "BSD simplified"
  :author "Marek Kochanowicz"
  :depends-on ( :iterate      :serapeum
                :prove        :cl-data-structures
                :lparallel    :metabang-bind
                :alexandria   :documentation-utils-extensions)
  :defsystem-depends-on (:prove-asdf)
  :serial T
  :pathname "src"
  :components ((:file "aux-package")
               (:module "column"
                :components ((:file "package")
                             (:file "protocol")
                             (:file "types")
                             (:file "conditions")
                             (:file "docstring")
                             (:file "internal")
                             (:file "implementation")
                             (:test-file "tests")))
               (:module "header"
                :components ((:file "package")))
               (:module "table"
                :components ((:file "package")))
               (:module "api"
                :components ((:file "package")))
               (:module "csv"
                :components ())))
