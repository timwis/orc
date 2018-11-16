(use orc)
(use matchable)
(use string-utils)
(use args)


(define (make-backing-store filename)
  (let ((db (open-backing-store filename)))
    (with-backing-store db initialise-backing-store)
    db))

(define (get-backing-store filename)
  (if (file-exists? filename)
    (open-backing-store filename)
    (make-backing-store filename)))

(define (get-register name/filename)
  (let ((stored-register (open-register name/filename)))
    (cond
      (stored-register
        stored-register)
      ((file-exists? name/filename)
        (with-input-from-file name/filename (cut read-rsf name/filename)))
      ((file-exists? (conc name/filename ".rsf"))
        (with-input-from-file (conc name/filename ".rsf") (cut read-rsf name/filename)))
      (else #f))))

(define (usage)
  (with-output-to-port (current-error-port) (lambda ()
    (print "Usage: " (car (argv)) "[OPTIONS...] COMMAND NAME [ARGS...]")
    (newline)
    (print (args:usage opts)))))

(define backing-store (make-parameter (make-backing-store 'memory)))

(define opts
  (list (args:make-option (S store) (#:required "BACKING-STORE.SQLITE") "Read and write to BACKING-STORE.SQLITE instead of RSF files."
          (backing-store (get-backing-store arg)))
        (args:make-option (? h help) #:none "Print help and exit."
          (usage)
          (exit 1))))

(receive (options args) (args:parse (command-line-arguments) opts)
  (with-backing-store (backing-store) (lambda ()
    (match args
      (("items" register-name region-name key-name)
        (and-let* ((register (get-register register-name))
                  (record (register-record-ref register (string->symbol region-name) (make-key key-name)))
                  (items (entry-items record))
                  (blobs (map item-blob items)))
          (for-each print blobs)))
      (("add-entry" register-name region-name key-name item-blobs ...)
          (and-let* ((register (get-register register-name))
                    (region (string->symbol region-name))
                    (key (make-key key-name))
                    (items (map make-item item-blobs))
                    (register (fold register-add-item register items))
                    (entry (make-entry region key (current-date) items))
                    (register (register-append-entry entry)))))
      (("digest" register-name)
          (and-let* ((register (get-register register-name))
                    (digest (register-root-digest register))
                    (hex (string->hex (blob->string digest))))
            (print hex)))
      (_ (usage))))))
