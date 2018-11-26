(use orc)
(use matchable)
(use string-utils)
(use args)
(use srfi-19)
(use files)

; Always create dates in UTC
(local-timezone-locale (utc-timezone-locale))

(define (make-backing-store filename)
  (let ((db (open-backing-store filename)))
    (with-backing-store db initialise-backing-store)
    (when (not (equal? filename 'memory))
      (fprintf (current-error-port) "Created new orc backing store at ~A\n" filename))
    db))

(define (get-backing-store filename)
  (if (file-exists? filename)
    (open-backing-store filename)
    (make-backing-store filename)))

(define (get-register name/filename)
  (let* ((base-name (pathname-file name/filename))
        (stored-register (open-register name/filename))
        (stored-register (or stored-register (open-register base-name))))
    (cond
      (stored-register
        stored-register)
      ((file-exists? name/filename)
        (with-input-from-file name/filename (cut read-rsf base-name)))
      ((file-exists? (conc name/filename ".rsf"))
        (with-input-from-file (conc name/filename ".rsf") (cut read-rsf base-name)))
      (else #f))))

(define commands
  '(("ls" "" "Print the names of Registers in this backing store.")
    ("init" "<REGISTER>" "Create a new Register with the given name.")
    ("keys" "<REGISTER> <REGION>" "Print all the keys in this Register region.")
    ("items" "<REGISTER> <REGION> <KEY>" "Print all the items for the given key.")
    ("add-entry" "<REGISTER> <REGION> <KEY> [<ITEM-BLOB> ...]" "Add a new entry with new item blobs to the Register.")
    ("digest" "<REGISTER>" "Print the root digest of the Register.")))

(define commands-column-widths
  (map
    (compose add1 (cut apply max <>))
    (map
      (cut map string-length <>)
      (call-with-values (cut unzip3 commands) list))))

(define (usage)
  (with-output-to-port (current-error-port) (lambda ()
    (print "Usage: " (car (argv)) " [OPTIONS...] COMMAND [ARGS...]")
    (newline)
    (args:width 26)
    (print (args:usage opts))
    (newline)
    (print "Commands:")
    (for-each (lambda (command)
        (for-each display (map string-pad-right command commands-column-widths))
        (newline))
      commands))))

(define backing-store (make-parameter (make-backing-store 'memory)))

(define opts
  (list (args:make-option (S store) (#:required "BACKING-STORE") "Read and write to BACKING-STORE instead of RSF files."
          (backing-store (get-backing-store arg)))
        (args:make-option (? h help) #:none "Print help and exit."
          (usage)
          (exit 1))))

(receive (options args) (args:parse (command-line-arguments) opts)
  (with-backing-store (backing-store) (lambda ()
    (match args
      (("ls")
        (for-each print (map first (list-registers))))
      (("init" register-name)
        (if (get-register register-name)
          (fprintf (current-error-port) "Already a Register with the name ~A!\n" register-name)
          (make-register register-name)))
      (("keys" register-name region-name)
        (and-let* ((register (get-register register-name))
                  (records (register-records register (string->symbol region-name)))
                  (keys (map (compose key->string entry-key) records)))
          (for-each print keys)))
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
                    (register (fold (flip register-add-item) register items))
                    (entry (apply make-entry (append (list region key (time->date (current-time))) items)))
                    (register (register-append-entry register entry)))))
      (("digest" register-name)
          (and-let* ((register (get-register register-name))
                    (digest (register-root-digest register))
                    (hex (string->hex (blob->string digest))))
            (print hex)))
      (_ (usage))))))
