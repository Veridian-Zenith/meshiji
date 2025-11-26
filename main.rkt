#lang racket

(require racket/cmdline)
(require racket/format)
(require racket/path)
(require racket/string)
(require "voix.rkt")
(require "auth.rkt")

(provide main
         display-help
         display-version)

;; Version information
(define version "1.0.0-racket")
(define program-name "voix")

;; Display help information
(define (display-help)
  (printf "~a - A Modern, Secure Sudo Replacement (Racket version)\n\n" program-name)
  (printf "Usage: ~a [options] <command> [args...]\n\n" program-name)
  (printf "Options:\n")
  (printf "  -h, --help          Show this help message\n")
  (printf "  -v, --version       Show version information\n")
  (printf "  -c, --config PATH   Use custom configuration file (default: /etc/voix.conf)\n")
  (printf "  check [config]      Validate configuration file\n")
  (printf "  validate [config]   Validate and show configuration rules\n\n")
  (printf "Examples:\n")
  (printf "  ~a systemctl status sshd     # Run command with elevated privileges\n" program-name)
  (printf "  ~a apt update                # Package management\n" program-name)
  (printf "  ~a check                     # Validate default config\n" program-name)
  (printf "  ~a check /path/to/config     # Validate custom config\n" program-name)
  (printf "  ~a validate                  # Show all rules\n" program-name))

;; Display version information
(define (display-version)
  (printf "~a version ~a\n" program-name version)
  (printf "Built with Racket ~a\n" (version))
  (printf "Configuration file: /etc/voix.conf\n")
  (printf "Log file: /var/log/voix.log\n"))

;; Check and validate configuration
(define (check-config config-path)
  (unless (file-exists? config-path)
    (error "Configuration file not found: ~a" config-path))

  (define rules (parse-config config-path))
  (when (empty? rules)
    (error "No rules found in configuration file"))

  (printf "Configuration file '~a' is valid.\n" config-path)
  (printf "Found ~a rule(s):\n" (length rules))
  (for ([rule rules])
    (printf "  ~a ~a ~a ~a\n"
            (if (rule-permit rule) "permit" "deny")
            (rule-user-or-group rule)
            (if (string=? (rule-cmd rule) "") "any command" (format "cmd ~a" (rule-cmd rule)))
            (string-join (filter identity (list (and (rule-persist rule) "persist")
                                                (and (rule-nopasswd rule) "nopasswd")
                                                (and (rule-keepenv rule) "keepenv"))) " ")))
  (printf "\nConfiguration validation successful.\n"))

;; Show detailed configuration validation
(define (validate-config config-path)
  (check-config config-path)
  (printf "\nDetailed validation:\n")

  (define current-user (get-current-user))
  (define rules (parse-config config-path))

  (for ([rule rules]
        [i (in-naturals 1)])
    (printf "\nRule ~a:\n" i)
    (printf "  Action: ~a\n" (if (rule-permit rule) "PERMIT" "DENY"))
    (printf "  Target: ~a\n" (rule-user-or-group rule))
    (printf "  Command: ~a\n" (if (string=? (rule-cmd rule) "") "any command" (rule-cmd rule)))
    (printf "  Target user: ~a\n" (rule-target-user rule))
    (printf "  Modifiers: ~a\n"
            (string-join (filter identity (list (and (rule-persist rule) "persist")
                                                (and (rule-nopasswd rule) "nopasswd")
                                                (and (rule-keepenv rule) "keepenv"))) " None"))

    ;; Check if rule applies to current user
    (define user-matches?
      (if (string-prefix? (rule-user-or-group rule) "group:")
          (check-user-group-membership current-user (substring (rule-user-or-group rule) 6))
          (string=? (rule-user-or-group rule) current-user)))

    (printf "  Applies to ~a: ~a\n" current-user (if user-matches? "YES" "NO"))))

;; Execute command with privilege escalation
(define (execute-voix-command command-args config-path)
  (when (empty? command-args)
    (error "No command specified"))

  (define current-user (get-current-user))
  (define command-string (string-join command-args))

  ;; Parse configuration
  (define rules (parse-config config-path))

  ;; Find matching rules
  (define matching-rules
    (filter (lambda (rule) (rule-matches rule current-user command-string)) rules))

  (when (empty? matching-rules)
    (log-message 4 (format "DENY user=~a cmd='~a'" current-user command-string) #t)
    (error "Command not permitted for user ~a" current-user))

  ;; Check for explicit denial (deny rules take precedence)
  (define deny-rule
    (for/first ([rule matching-rules] #:when (not (rule-permit rule))) rule))

  (when deny-rule
    (log-message 4 (format "DENY user=~a cmd='~a' (explicit deny rule)"
                           current-user command-string) #t)
    (error "Command explicitly denied"))

  ;; Use the most permissive rule (first matching permit rule)
  (define permit-rule
    (for/first ([rule matching-rules] #:when (rule-permit rule)) rule))

  (unless permit-rule
    (error "No permit rule found for this command"))

  ;; Extract rule properties
  (define target-user (rule-target-user permit-rule))
  (define keep-env (rule-keepenv permit-rule))
  (define nopasswd (rule-nopasswd permit-rule))
  (define can-persist (rule-persist permit-rule))

  ;; Authentication check
  (define authenticated
    (or nopasswd
        (and can-persist (is-auth-valid current-user))
        (authenticate-and-escalate current-user (make-default-config))))

  (unless authenticated
    (error "Authentication failed"))

  ;; Environment handling
  (unless keep-env
    (scrub-env))

  ;; Execute the command
  (define user-shell (get-user-shell target-user))
  (execute-command command-string target-user user-shell))

;; Main entry point
(define (main args)
  (define config-path "/etc/voix.conf")
  (define show-help? #f)
  (define show-version? #f)

  (command-line
   #:program program-name
   #:once-each
   [("-h" "--help") "Show help message"
    (set! show-help? #t)]
   [("-v" "--version") "Show version information"
    (set! show-version? #t)]
   [("-c" "--config") path "Use custom configuration file"
    (set! config-path path)]
   #:args rest-args

  (cond
    [show-help?
     (display-help)]
    [show-version?
     (display-version)]
    [(empty? rest-args)
     (display-help)
     (exit 2)]
    [else
     (define command (first rest-args))
     (define command-args (rest rest-args))

     (cond
       [(or (string=? command "help") (string=? command "--help"))
        (display-help)]
       [(or (string=? command "version") (string=? command "--version"))
        (display-version)]
       [(string=? command "check")
        (define check-config-path (if (empty? command-args) config-path (first command-args)))
        (check-config check-config-path)]
       [(string=? command "validate")
        (define validate-config-path (if (empty? command-args) config-path (first command-args)))
        (validate-config validate-config-path)]
       [else
        (with-handlers ([exn:fail? (lambda (e)
                                     (eprintf "Error: ~a\n" (exn-message e))
                                     (exit 1))])
          (execute-voix-command (cons command command-args) config-path))])])))

;; Start the program if this is the main module
(module+ main
  (main (current-command-line-arguments)))
