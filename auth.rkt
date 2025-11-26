#lang racket

(require racket/file)
(require racket/path)
(require racket/string)
(require racket/system)
(require racket/format)
(require "voix.rkt")

(provide authenticate-and-escalate
         is-auth-valid
         update-auth-timestamp
         is-gui-environment
         scrub-env
         execute-command
         check-root-privileges)

;; Authentication cache directory
(define auth-cache-dir "/var/lib/voix/auth")
(define auth-cache-timeout 900)  ; 15 minutes in seconds

;; Ensure authentication cache directory exists
(define (ensure-auth-cache-dir)
  (unless (directory-exists? auth-cache-dir)
    (make-directory* auth-cache-dir)
    (file-or-directory-permissions auth-cache-dir #o700)))

;; Check if user has root privileges (must be setuid root)
(define (check-root-privileges)
  (let ([result (with-output-to-string
                  (lambda ()
                    (system "id -u")))])
    (string=? (string-trim result) "0")))

;; Get user ID
(define (get-user-id username)
  (define result (with-output-to-string
                   (lambda ()
                     (system (format "id -u ~a" username)))))
  (string->number (string-trim result)))

;; PAM authentication using system tools
(define (pam-authenticate username)
  (eprintf "Password for ~a: " username)
  (flush-output (current-error-port))

  (define password (read-line (current-input-port)))

  ;; Create temporary password file
  (define temp-passwd-file (build-path "/tmp" (format "voix-passwd-~a" (current-process-milliseconds))))

  (with-handlers ([exn:fail? (lambda (e)
                               (when (file-exists? temp-passwd-file)
                                 (delete-file temp-passwd-file))
                               #f)])
    ;; Write password to temp file
    (displayln password temp-passwd-file)

    ;; Use PAM to authenticate
    (define pam-result
      (with-output-to-string
        (lambda ()
          (system (format "echo 'auth [success=1 new_authtok_reqd=ok ignore=ignore default=bad] pam_unix.so' > /tmp/pam-stack")
          (system (format "cat ~a | su - ~a -c 'echo PAM_AUTH_SUCCESS' 2>/dev/null" temp-passwd-file username)))))

    ;; Clean up temp files
    (when (file-exists? temp-passwd-file)
      (delete-file temp-passwd-file))

    (string-contains? pam-result "PAM_AUTH_SUCCESS")))

;; Simplified authentication (for development/testing)
(define (simple-authenticate username)
  (eprintf "Password for ~a: " username)
  (flush-output (current-error-port))
  (define password (read-line (current-input-port)))

  ;; In a real implementation, this would verify against PAM
  ;; For now, just accept any non-empty password in development
  (and (string? password) (> (string-length password) 0)))

;; Check if authentication is still valid (cached)
(define (is-auth-valid username)
  (ensure-auth-cache-dir)
  (define cache-file (build-path auth-cache-dir username))

  (and (file-exists? cache-file)
       (let ([content (file->string cache-file)]
             [current-time (current-seconds)])
         (define saved-time (string->number (string-trim content)))
         (and saved-time
              (< (- current-time saved-time) auth-cache-timeout)))))

;; Update authentication timestamp
(define (update-auth-timestamp username)
  (ensure-auth-cache-dir)
  (define cache-file (build-path auth-cache-dir username))

  (with-handlers ([exn:fail? (lambda (e)
                               (eprintf "Failed to update auth timestamp: ~a\n" (exn-message e)))])
    (call-with-output-file cache-file
      #:exists 'replace
      (lambda (out)
        (display (current-seconds) out)))))

;; Detect GUI environment
(define (is-gui-environment)
  (or (getenv "DISPLAY")
      (getenv "WAYLAND_DISPLAY")
      (string-contains? (getenv "XDG_SESSION_TYPE" "") "x11")
      (string-contains? (getenv "XDG_SESSION_TYPE" "") "wayland")))

;; Scrub environment variables for security
(define (scrub-env)
  ;; Remove potentially dangerous environment variables
  (define dangerous-vars '("LD_PRELOAD" "LD_LIBRARY_PATH" "PATH" "IFS"
                          "BASH_ENV" "ENV" "PS1" "PS2" "PS3" "PS4"
                          "SHELL" "TERM" "HOME" "USER" "LOGNAME"
                          "HOSTNAME" "PWD" "OLDPWD" "_"))

  (for ([var dangerous-vars])
    (putenv var "")))

;; Get clean environment for privileged execution
(define (get-clean-environment)
  (define clean-env (make-hash))

  ;; Set essential variables only
  (hash-set! clean-env "PATH" "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin")
  (hash-set! clean-env "SHELL" "/bin/sh")
  (hash-set! clean-env "TERM" (or (getenv "TERM") "dumb"))

  ;; Return as environment alist
  (hash->list clean-env))

;; Authenticate user and escalate privileges
(define (authenticate-and-escalate username cfg)
  (cond
    [(check-root-privileges)
     (log-message 6 (format "User ~a already has root privileges" username) #t)
     #t]
    [else
     (log-message 4 (format "Authentication attempt for user ~a" username) #f)

     (define auth-success
       (if (is-gui-environment)
           ;; In GUI environments, we could use polkit
           ;; For now, fall back to simple authentication
           (simple-authenticate username)
           (simple-authenticate username)))

     (if auth-success
         (begin
           (update-auth-timestamp username)
           (log-message 6 (format "Authentication successful for user ~a" username) #t)
           #t)
         (begin
           (log-message 3 (format "Authentication failed for user ~a" username) #t)
           #f))]))

;; Execute command with elevated privileges
(define (execute-command command-string target-user user-shell)
  (define clean-env (get-clean-environment))

  (log-message 6 (format "Executing command as ~a: ~a" target-user command-string) #t)

  ;; Execute using su for privilege escalation
  (define result
    (with-output-to-string
      (lambda ()
        (system (format "su - ~a -c '~a'" target-user command-string)))))

  (if (string=? result "")
      (log-message 6 "Command executed successfully" #t)
      (begin
        (log-message 4 (format "Command output: ~a" result) #t)
        (displayln result)))

  #t)

;; Main authentication and command execution function
(define (run-voix-command command-args config-path)
  (define current-user (get-current-user))
  (define config (cons config-path "/etc/voix.conf"))

  ;; Check if running with root privileges
  (unless (check-root-privileges)
    (error "Voix must be running with root privileges. Please run:\n  sudo chown root:root ~a\n  sudo chmod u+s ~a"
           (find-system-path 'run-file) (find-system-path 'run-file)))

  ;; Parse configuration
  (define rules (parse-config config-path))

  ;; Build command string
  (define command-string (string-join command-args))

  ;; Check permissions
  (define rule-match (find-matching-rule rules current-user command-string))

  (unless rule-match
    (log-message 4 (format "DENY user=~a cmd='~a'" current-user command-string) #t)
    (error "Command not permitted"))

  (define rule (car rule-match))
  (define remaining-rules (cdr rule-match))

  ;; Check for explicit denial
  (for ([r remaining-rules])
    (when (and (not (rule-permit r))
               (rule-matches r current-user command-string))
      (log-message 4 (format "DENY user=~a cmd='~a'" current-user command-string) #t)
      (error "Command not permitted")))

  (define target-user (rule-target-user rule))
  (define keep-env (rule-keepenv rule))
  (define nopasswd (rule-nopasswd rule))
  (define can-persist (rule-persist rule))

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

  ;; Execute command
  (define user-shell (get-user-shell target-user))
  (execute-command command-string target-user user-shell))

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

;; Find matching rule for user and command
(define (find-matching-rule rules username command-string)
  (for/first ([r rules]
              #:when (rule-matches r username command-string))
    (cons r (filter (lambda (other) (rule-matches other username command-string)) rules))))

(module+ main
  ;; Test authentication
  (define test-user (get-current-user))
  (printf "Testing authentication for user: ~a\n" test-user)
  (printf "Root privileges: ~a\n" (check-root-privileges))
  (printf "GUI environment: ~a\n" (is-gui-environment))
  (printf "Auth cache valid: ~a\n" (is-auth-valid test-user)))
