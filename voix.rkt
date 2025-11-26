#lang racket

(require racket/hash)
(require racket/file)
(require racket/path)
(require racket/string)
(require racket/system)
(require racket/exn)
(require json)

(provide rule?
        rule-permit
        rule-user-or-group
        rule-target-user
        rule-cmd
        rule-persist
        rule-nopasswd
        rule-keepenv
        parse-config
        parse-config-string
        validate-config-path
        ensure-config-dir
        log-message
        current-log-file
        set-current-log-file!
        check-user-group-membership
        get-current-user
        get-user-shell
        make-default-config
        validate-config
        rule-matches)

;; Core data structure for configuration rules
(struct rule (permit user-or-group target-user cmd persist nopasswd keepenv) #:prefab)

;; Configuration structure
(struct config (log-file max-auth-attempts users) #:prefab)

;; Global state for logging
(define current-log-file "/var/log/voix.log")

(define (set-current-log-file! path)
  (set! current-log-file path))

;; Validate configuration file path for security
(define (validate-config-path path)
  (cond
    [(or (string=? path "") (> (string-length path) 512)) #f]
    [(or (string-contains? path "..")
         (string-contains? path "//")
         (string-contains? path "~")) #f]
    [(not (eq? (string-ref path 0) #\/)) #f]
    [else #t]))

;; Ensure configuration directory exists
(define (ensure-config-dir dir)
  (unless (directory-exists? dir)
    (make-directory* dir)
    (file-or-directory-permissions dir #o755)))

;; Get current username
(define (get-current-user)
  (parameterize ([current-input-port (open-input-string "")])
    (let ([result (with-output-to-string
                    (lambda ()
                      (system "whoami")))])
      (string-trim result))))

;; Get user's shell
(define (get-user-shell username)
  (let* ([passwd-file "/etc/passwd"]
         [content (file->string passwd-file)]
         [lines (string-split content "\n")])
    (for/first ([line lines]
                #:when (string-contains? line (format "~a:" username)))
      (let ([fields (string-split line ":")])
        (if (> (length fields) 6)
            (list-ref fields 6)
            "/bin/sh")))))

;; Check if user is in system group
(define (check-user-group-membership username group-name)
  (let* ([result (with-output-to-string
                   (lambda ()
                     (system (format "groups ~a" username))))])
    (string-contains? (string-trim result) group-name)))

;; Trim whitespace from both ends
(define (string-trim-both str)
  (define (trim-left s)
    (regexp-replace* #px"^\\s+" s ""))
  (define (trim-right s)
    (regexp-replace* #px"\\s+$" s ""))
  (trim-right (trim-left str)))

;; Parse configuration file with modern syntax
(define (parse-config path)
  (cond
    [(not (validate-config-path path))
     (error (format "Invalid config file path: ~a" path))]
    [(not (file-exists? path))
     (error (format "Configuration file not found: ~a" path))]
    [else
     (let ([content (file->string path)])
       (parse-config-string content path))]))

;; Parse configuration from string content
(define (parse-config-string content [path "/etc/voix.conf"])
  (define lines (string-split content "\n"))
  (define rules '())

  (for ([line lines]
        [line-number (in-naturals 1)])
    (define trimmed (string-trim-both line))

    ;; Skip empty lines and comments
    (when (and (not (string=? trimmed ""))
               (not (eq? (string-ref trimmed 0) #\#)))
      (let ([rule (parse-rule-line trimmed line-number path)])
        (when rule
          (set! rules (cons rule rules))))))

  (reverse rules))

;; Parse individual rule line
(define (parse-rule-line line line-number path)
  (define words (string-split line))
  (cond
    [(empty? words) #f]
    [else
     (define first-word (first words))
     (cond
       [(or (string=? first-word "permit") (string=? first-word "deny"))
        (parse-permit-deny-line first-word (rest words) line-number)]
       [else
        (eprintf "Warning: Unknown rule type on line ~a of ~a: ~a\n"
                 line-number path first-word)
        #f])]))

;; Parse permit/deny rule - fixed implementation
(define (parse-permit-deny-line permit-deny words line-number)
  (when (empty? words)
    (error (format "Rule missing user/group on line ~a" line-number)))

  (define permit? (string=? permit-deny "permit"))
  (define user-or-group (first words))
  (define rest-words (rest words))

  ;; Create rule with defaults
  (define rule-struct (rule permit? user-or-group "root" "" #f #f #f))

  ;; Parse modifiers - manual construction to avoid struct-copy issues
  (define updated-rule
    (for/fold ([rule rule-struct]) ([word rest-words])
      (cond
        [(string=? word "persist")
         (rule (rule-permit rule) (rule-user-or-group rule) (rule-target-user rule)
               (rule-cmd rule) #t (rule-nopasswd rule) (rule-keepenv rule))]
        [(string=? word "nopasswd")
         (rule (rule-permit rule) (rule-user-or-group rule) (rule-target-user rule)
               (rule-cmd rule) (rule-persist rule) #t (rule-keepenv rule))]
        [(string=? word "keepenv")
         (rule (rule-permit rule) (rule-user-or-group rule) (rule-target-user rule)
               (rule-cmd rule) (rule-persist rule) (rule-nopasswd rule) #t)]
        [(string=? word "as")
         (if (>= (length rest-words) 2)
             (rule (rule-permit rule) (rule-user-or-group rule) (second rest-words)
                   (rule-cmd rule) (rule-persist rule) (rule-nopasswd rule) (rule-keepenv rule))
             rule)]
        [(string=? word "cmd")
         (define cmd-index (+ 1 (list-index (curry string=? word) rest-words)))
         (if (< cmd-index (length rest-words))
             (rule (rule-permit rule) (rule-user-or-group rule) (rule-target-user rule)
                   (string-join (drop rest-words cmd-index)) (rule-persist rule) (rule-nopasswd rule) (rule-keepenv rule))
             rule)]
        [else
         ;; If we encounter an unknown word and don't have a command yet,
         ;; treat everything from here as the command
         (rule (rule-permit rule) (rule-user-or-group rule) (rule-target-user rule)
               (string-join (cons word (drop rest-words (+ 1 (list-index (curry string=? word) rest-words)))))
               (rule-persist rule) (rule-nopasswd rule) (rule-keepenv rule))])))

  ;; Validate rule
  (when (empty? (rule-user-or-group updated-rule))
    (error (format "Invalid rule: missing user/group on line ~a" line-number)))

  updated-rule)

;; Check if a rule matches the user and command
(define (rule-matches rule username command-string)
  (define user-matches?
    (if (string-prefix? (rule-user-or-group rule) "group:")
        (check-user-group-membership username (substring (rule-user-or-group rule) 6))
        (string=? (rule-user-or-group rule) username)))

  (define cmd-matches?
    (or (string=? (rule-cmd rule) "")
        (string-prefix? command-string (rule-cmd rule))
        (string=? command-string (rule-cmd rule))))

  (and user-matches? cmd-matches?))

;; JSON logging system
(define (log-message level message [log-file current-log-file] [to-stdout #f])
  (define timestamp (current-seconds))
  (define log-entry (hasheq 'timestamp timestamp
                            'level level
                            'message message
                            'user (get-current-user)))

  (when to-stdout
    (displayln message))

  (when (and log-file (string? log-file))
    (with-handlers ([exn:fail? (lambda (e)
                                 (eprintf "Failed to write to log file ~a: ~a\n"
                                          log-file (exn-message e)))])
      (call-with-output-file log-file
        #:exists 'append
        (lambda (out)
          (write-json log-entry out)
          (newline out))))))

;; Default configuration
(define (make-default-config)
  (config current-log-file 3 '()))

;; Validate configuration
(define (validate-config rules)
  (for ([rule rules])
    (unless (rule-user-or-group rule)
      (error "Invalid rule: missing user_or_group"))
    (when (and (rule-nopasswd rule) (not (rule-permit rule)))
      (eprintf "Warning: nopasswd on deny rule is ineffective for rule: ~a\n"
               (rule-user-or-group rule))))
  rules)

(module+ main
  ;; Basic test
  (define test-config "permit persist testuser as root\npermit testuser cmd /bin/ls")
  (define rules (parse-config-string test-config))
  (for ([rule rules])
    (printf "Rule: ~a ~a ~a ~a\n"
            (if (rule-permit rule) "permit" "deny")
            (rule-user-or-group rule)
            (if (string=? (rule-cmd rule) "") "any command" (rule-cmd rule))
            (string-join (filter identity (list (and (rule-persist rule) "persist")
                                                (and (rule-nopasswd rule) "nopasswd")
                                                (and (rule-keepenv rule) "keepenv"))) " "))))
