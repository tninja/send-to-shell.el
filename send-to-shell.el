;;; send-to-shell.el --- Send code to shell buffers with multiple backends

;;; Commentary:
;; send-to-shell provides a unified interface for sending code to various
;; shell backends (shell, vterm, eat, ghostel) from source buffers.
;; Each source buffer gets its own dedicated shell buffer.

;;; Code:

;; DONE: ghostel backend start shell now starts in other window without overlapping the source buffer. See /home/tninja/.emacs.d/elpa/ghostel-20260502.2158 for upstream window behavior details.

;; TODO: ghostel backend start report wrong number of argument, 5

;; DONE: the eat backend now loads the eat library on demand and starts it in another window, so start shell no longer silently does nothing when eat is installed but not yet loaded.

;; DONE: eat started buffer now gets renamed from *eat* to the source buffer name, so if the source buffer is test.sh the eat buffer becomes *test.sh*.

(defgroup send-to-shell nil
  "Send code to shell buffers with multiple backends."
  :group 'tools
  :prefix "send-to-shell-")

(defcustom send-to-shell-default-backend 'shell
  "Default shell backend to use."
  :type '(choice (const shell)
                 (const vterm)
                 (const eat)
                 (const ghostel))
  :group 'send-to-shell)

(defcustom send-to-shell-vterm-sleep-ms 100
  "Sleep duration in milliseconds after sending to vterm."
  :type 'integer
  :group 'send-to-shell)

;;; Backend Management

(defun send-to-shell--feature-available-p (feature)
  "Return non-nil when FEATURE is loaded or its library is installed."
  (or (featurep feature)
      (locate-library (symbol-name feature))))

(defun send-to-shell--load-feature-if-available (feature)
  "Return non-nil when FEATURE is loaded or can be loaded."
  (or (featurep feature)
      (and (locate-library (symbol-name feature))
           (require feature nil t))))

(defun send-to-shell-get-available-backends ()
  "Return a list of available shell backends."
  (let (backends)
    (dolist (backend send-to-shell--backend-definitions (nreverse backends))
      (when (funcall (send-to-shell--backend-handler (car backend) :available))
        (push (car backend) backends)))))

(defun send-to-shell-get-shell-buffer-name ()
  "Get the shell buffer name for the current buffer."
  (format "*%s*" (buffer-name)))

(defun send-to-shell--shell-backend-available-p ()
  "Return non-nil when the shell backend is available."
  t)

(defun send-to-shell--vterm-backend-available-p ()
  "Return non-nil when the vterm backend is available."
  (featurep 'vterm))

(defun send-to-shell--eat-backend-available-p ()
  "Return non-nil when the eat backend is available."
  (send-to-shell--feature-available-p 'eat))

(defun send-to-shell--ghostel-backend-available-p ()
  "Return non-nil when the ghostel backend is available."
  (featurep 'ghostel))

(defconst send-to-shell--backend-definitions
  '((shell
     :available send-to-shell--shell-backend-available-p
     :send send-to-shell--send-to-shell
     :start send-to-shell--start-shell-backend)
    (vterm
     :available send-to-shell--vterm-backend-available-p
     :send send-to-shell--send-to-vterm
     :start send-to-shell--start-vterm-backend)
    (eat
     :available send-to-shell--eat-backend-available-p
     :send send-to-shell--send-to-eat
     :start send-to-shell--start-eat-backend)
    (ghostel
     :available send-to-shell--ghostel-backend-available-p
     :send send-to-shell--send-to-ghostel
     :start send-to-shell--start-ghostel-backend))
  "Backend configuration table for send-to-shell.")

(defun send-to-shell--backend-property (backend property)
  "Return PROPERTY from BACKEND definition."
  (plist-get (cdr (assq backend send-to-shell--backend-definitions))
             property))

(defun send-to-shell--backend-handler (backend property)
  "Return BACKEND handler function for PROPERTY."
  (or (send-to-shell--backend-property backend property)
      (error "Unknown backend: %s" backend)))

(defun send-to-shell--call-backend-handler (backend property &rest args)
  "Call BACKEND PROPERTY handler with ARGS."
  (apply (send-to-shell--backend-handler backend property) args))

;;; Backend-Specific Implementations

(defun send-to-shell--missing-shell-error (shell-buf-name)
  "Signal a user error for missing SHELL-BUF-NAME."
  (user-error "Shell buffer %s does not exist. Start or switch to shell first"
              shell-buf-name))

(defun send-to-shell--ensure-send-target-exists (backend shell-buf-name)
  "Ensure BACKEND has an existing SHELL-BUF-NAME before sending."
  (pcase backend
    ('shell
     (unless (comint-check-proc shell-buf-name)
       (send-to-shell--missing-shell-error shell-buf-name)))
    (_
     (unless (get-buffer shell-buf-name)
       (send-to-shell--missing-shell-error shell-buf-name)))))

(defun send-to-shell--send-to-shell (start end shell-buf-name)
  "Send region to shell buffer."
  (let ((text (buffer-substring start end)))
    (send-to-shell--ensure-send-target-exists 'shell shell-buf-name)
    (ignore-errors
      (comint-send-string shell-buf-name (concat text "\n")))))

(defun send-to-shell--send-via-comint (start end shell-buf-name backend)
  "Send region to buffer for BACKEND via comint."
  (let ((text (buffer-substring start end)))
    (send-to-shell--ensure-send-target-exists backend shell-buf-name)
    (comint-send-string shell-buf-name text)
    (comint-send-string shell-buf-name "\n")))

(defun send-to-shell--send-to-vterm (start end shell-buf-name)
  "Send region to vterm buffer."
  (when (featurep 'vterm)
    (send-to-shell--send-via-comint start end shell-buf-name 'vterm)
    (sleep-for 0 send-to-shell-vterm-sleep-ms)))

(defun send-to-shell--send-to-eat (start end shell-buf-name)
  "Send region to eat buffer."
  (when (featurep 'eat)
    (send-to-shell--send-via-comint start end shell-buf-name 'eat)))

(defun send-to-shell--rename-current-buffer-to (shell-buf-name)
  "Rename the current buffer to SHELL-BUF-NAME.
Replace an existing placeholder buffer with that name when present."
  (unless (equal (buffer-name) shell-buf-name)
    (when (get-buffer shell-buf-name)
      (kill-buffer shell-buf-name))
    (rename-buffer shell-buf-name)))

(defun send-to-shell--start-named-eat-in-other-window (shell-buf-name)
  "Start eat in another window and rename its terminal buffer to SHELL-BUF-NAME."
  (when (send-to-shell--load-feature-if-available 'eat)
    (let* ((existing-buffer (get-buffer shell-buf-name))
           (window
            (send-to-shell--display-buffer-in-other-window
             (or existing-buffer (current-buffer)))))
      (with-selected-window window
        (unless (derived-mode-p 'eat-mode)
          (eat)
          (with-current-buffer (window-buffer window)
            (send-to-shell--rename-current-buffer-to shell-buf-name)))))))

(defun send-to-shell--start-named-ghostel-in-other-window (shell-buf-name)
  "Start ghostel using SHELL-BUF-NAME in another window."
  (let ((ghostel-buffer-name shell-buf-name))
    (with-selected-window
        (send-to-shell--display-buffer-in-other-window
         (get-buffer-create shell-buf-name))
      (unless (derived-mode-p 'ghostel-mode)
        (ghostel)))))

(defun send-to-shell--send-to-ghostel (start end shell-buf-name)
  "Send region to ghostel buffer."
  (when (featurep 'ghostel)
    (let ((text (buffer-substring start end)))
      (send-to-shell--ensure-send-target-exists 'ghostel shell-buf-name)
      (comint-send-string shell-buf-name text)
      (comint-send-string shell-buf-name "\n"))))

;;; Core Functions

(defun send-to-shell--call-with-point-preserved (fn)
  "Call FN and restore point afterward."
  (let ((old-point (point)))
    (funcall fn)
    (goto-char old-point)))

(defun send-to-shell-send-region (start end backend)
  "Send region to shell buffer using specified BACKEND.
START and END define the region to send."
  (let ((shell-buf-name (send-to-shell-get-shell-buffer-name)))
    (send-to-shell--call-backend-handler backend :send
                                         start end shell-buf-name)))

(defun send-to-shell-send-block (backend)
  "Send current block/paragraph to shell using BACKEND."
  (send-to-shell--call-with-point-preserved
   (lambda ()
     (mark-paragraph)
     (send-to-shell-send-region (region-beginning) (region-end) backend))))

(defun send-to-shell-send-region-or-block (backend)
  "Send selected region or current block to shell using BACKEND.
If a region is active, send it. Otherwise send the current block."
  (if (region-active-p)
      (send-to-shell--call-with-point-preserved
       (lambda ()
         (send-to-shell-send-region (region-beginning) (region-end) backend)))
    (send-to-shell-send-block backend)))

(defun send-to-shell-send-current-line (backend)
  "Send the current line to shell using BACKEND."
  (send-to-shell--call-with-point-preserved
   (lambda ()
     (send-to-shell-send-region (line-beginning-position)
                                (line-end-position)
                                backend))))

(defun send-to-shell--start-shell-backend (shell-buf-name)
  "Start the shell backend using SHELL-BUF-NAME."
  (send-to-shell--start-buffer-with-mode-in-other-window
   shell-buf-name 'shell-mode
   (lambda () (send-to-shell--start-named-shell shell-buf-name))))

(defun send-to-shell--start-vterm-backend (shell-buf-name)
  "Start the vterm backend using SHELL-BUF-NAME."
  (send-to-shell--start-buffer-if-missing
   shell-buf-name 'vterm #'vterm-other-window))

(defun send-to-shell--start-eat-backend (shell-buf-name)
  "Start the eat backend using SHELL-BUF-NAME."
  (send-to-shell--start-named-eat-in-other-window shell-buf-name))

(defun send-to-shell--start-ghostel-backend (shell-buf-name)
  "Start the ghostel backend using SHELL-BUF-NAME."
  (when (featurep 'ghostel)
    (send-to-shell--start-named-ghostel-in-other-window shell-buf-name)))

(defun send-to-shell--start-buffer-with-mode (shell-buf-name mode init-fn)
  "Start SHELL-BUF-NAME with MODE by calling INIT-FN when needed."
  (with-current-buffer (get-buffer-create shell-buf-name)
    (unless (eq major-mode mode)
      (funcall init-fn))))

(defun send-to-shell--start-buffer-if-missing (shell-buf-name feature init-fn)
  "Start SHELL-BUF-NAME via INIT-FN when FEATURE is available."
  (when (featurep feature)
    (unless (get-buffer shell-buf-name)
      (funcall init-fn)
      (rename-buffer shell-buf-name))))

(defun send-to-shell--display-buffer-in-other-window (buffer)
  "Display BUFFER in another window and return the window."
  (or (display-buffer
       buffer
       '((display-buffer-pop-up-window)
         (inhibit-same-window . t)))
      (selected-window)))

(defun send-to-shell--start-buffer-with-mode-in-other-window (shell-buf-name mode init-fn)
  "Start SHELL-BUF-NAME with MODE in another window using INIT-FN."
  (with-selected-window
      (send-to-shell--display-buffer-in-other-window
       (get-buffer-create shell-buf-name))
    (send-to-shell--start-buffer-with-mode shell-buf-name mode init-fn)))

(defun send-to-shell--ensure-sh-mode ()
  "Ensure `send-to-shell-start-shell' is called from `sh-mode'."
  (unless (derived-mode-p 'sh-mode)
    (user-error "send-to-shell-start-shell requires sh-mode")))

(defun send-to-shell--start-named-shell (shell-buf-name)
  "Start shell using SHELL-BUF-NAME."
  (save-current-buffer
    (ignore-errors (shell shell-buf-name))))

(defun send-to-shell-start-shell (backend)
  "Start a shell buffer for the current buffer using BACKEND."
  ;; DONE: shell should start in other window. It shouldn't overlap the source buffer.
  ;; DONE: to use this command, current buffer major mode must be sh-mode, otherwise, just let user know the error
  ;; DONE: started shell should have the same name as the source buffer, but with * around it. For example, if source buffer is test.sh, shell buffer should be *test.sh*. And corresponding send to shell command should send to *test.sh* buffer.
  (interactive (list send-to-shell-default-backend))
  (send-to-shell--ensure-sh-mode)
  (let ((shell-buf-name (send-to-shell-get-shell-buffer-name)))
    (send-to-shell--call-backend-handler backend :start shell-buf-name)))

(defun send-to-shell--transient-set-backend (backend)
  "Set `send-to-shell-default-backend' to BACKEND."
  (setq send-to-shell-default-backend backend)
  (message "send-to-shell backend set to %s" backend))

(defun send-to-shell--transient-select-backend ()
  "Prompt for a backend and set it as the transient default."
  (interactive)
  (send-to-shell--transient-set-backend (send-to-shell--select-backend)))

(defun send-to-shell--select-backend-description (&rest _)
  "Dynamic description for the backend selection menu item."
  (format "Switch backend (%s)" (symbol-name send-to-shell-default-backend)))

(defun send-to-shell--transient-start-or-switch-shell ()
  "Start or switch to a shell for `send-to-shell-default-backend'."
  (interactive)
  (send-to-shell-start-shell send-to-shell-default-backend))

(defun send-to-shell--transient-send-region ()
  "Send the active region using `send-to-shell-default-backend'."
  (interactive)
  (send-to-shell-send-region (region-beginning) (region-end)
                             send-to-shell-default-backend))

(defun send-to-shell--transient-send-block ()
  "Send the current block using `send-to-shell-default-backend'."
  (interactive)
  (send-to-shell-send-block send-to-shell-default-backend))

(defun send-to-shell--transient-send-region-or-block ()
  "Send the active region or current block using the transient backend."
  (interactive)
  (send-to-shell-send-region-or-block send-to-shell-default-backend))

(defun send-to-shell--transient-send-current-line ()
  "Send the current line using the transient backend."
  (interactive)
  (send-to-shell-send-current-line send-to-shell-default-backend))

(defvar send-to-shell--transient-prefix-command nil
  "Internal transient prefix command for `send-to-shell'.")

(eval-after-load 'transient
  '(transient-define-prefix send-to-shell-transient-menu ()
     "Transient menu for send-to-shell."
     [["Backend"
       ;; DONE: similar to ai-code--select-backend-description in ai-code.el, the Switch backend menu item now shows the currently selected backend.
       ("b" send-to-shell--transient-select-backend
        :description send-to-shell--select-backend-description)
       ;; DONE: renamed the transient shell action to Start or switch to shell, and updated the corresponding function name to match the actual behavior when a shell already exists.
       ("z" "Start or switch to shell" send-to-shell--transient-start-or-switch-shell)
       ;; DONE: send region, block, or current line now reports a user error and quits when the corresponding shell does not exist.
       ("c" "Send region or block" send-to-shell--transient-send-region-or-block)
       ;; DONE: added a transient menu item for sending the current line.
       ("n" "Send current line" send-to-shell--transient-send-current-line)
       ]]))

(defun send-to-shell ()
  "Main entry point for send-to-shell package.
Shows an interactive menu (if transient available) or prompts for backend selection."
  (interactive)
  (if (require 'transient nil t)
      (send-to-shell--transient-dispatcher)
    (send-to-shell--fallback-menu)))

(defun send-to-shell--select-backend ()
  "Prompt user to select a shell backend."
  (let* ((backends (send-to-shell-get-available-backends))
         (backend-names (mapcar #'symbol-name backends)))
    (intern (completing-read "Select shell backend: " backend-names
                             nil t nil nil nil))))

(defun send-to-shell--fallback-menu ()
  "Fallback menu when transient is not available."
  (let* ((backend (send-to-shell--select-backend))
         (action (send-to-shell--select-action)))
    (send-to-shell--perform-action action backend)))

(defun send-to-shell--select-action ()
  "Prompt user to select an action."
  (let ((actions '(("Send region" . region)
                   ("Send block" . block)
                   ("Send region or block" . region-or-block)
                   ("Send current line" . current-line))))
    (cdr (assoc (completing-read "Select action: " (mapcar #'car actions) nil t)
                actions))))

(defun send-to-shell--perform-action (action backend)
  "Perform the selected ACTION using the specified BACKEND."
  (pcase action
    ('region (send-to-shell-send-region (region-beginning) (region-end) backend))
    ('block (send-to-shell-send-block backend))
    ('region-or-block (send-to-shell-send-region-or-block backend))
    ('current-line (send-to-shell-send-current-line backend))
    (_ (message "Unknown action: %s" action))))

(defun send-to-shell--transient-dispatcher ()
  "Dispatcher for the transient menu."
  (send-to-shell-transient-menu))

;; DONE: similar to /home/tninja/.emacs.d/.emacs/languages.el, added an interactive function to register sh-mode keybindings for switch-to-shell, send-current-line, and send-region-or-block.

(defun send-to-shell-register-sh-mode-keybindings ()
  "Register send-to-shell keybindings for `sh-mode'."
  (interactive)
  (require 'sh-script)
  (define-key sh-mode-map (kbd "C-c C-s")
              #'send-to-shell)
  (define-key sh-mode-map (kbd "C-c C-z")
              #'send-to-shell--transient-start-or-switch-shell)
  (define-key sh-mode-map (kbd "C-c C-n")
              #'send-to-shell--transient-send-current-line)
  (define-key sh-mode-map (kbd "C-c C-c")
              #'send-to-shell--transient-send-region-or-block))

(provide 'send-to-shell)
;;; send-to-shell.el ends here
