;;; send-to-shell.el --- Send code to shell buffers with multiple backends

;;; Commentary:
;; send-to-shell provides a unified interface for sending code to various
;; shell backends (eshell, shell, vterm, eat, ghostel) from source buffers.
;; Each source buffer gets its own dedicated shell buffer.

;;; Code:

(defgroup send-to-shell nil
  "Send code to shell buffers with multiple backends."
  :group 'tools
  :prefix "send-to-shell-")

(defcustom send-to-shell-default-backend 'eshell
  "Default shell backend to use."
  :type '(choice (const eshell)
                 (const shell)
                 (const vterm)
                 (const eat)
                 (const ghostel))
  :group 'send-to-shell)

(defcustom send-to-shell-vterm-sleep-ms 100
  "Sleep duration in milliseconds after sending to vterm."
  :type 'integer
  :group 'send-to-shell)

;;; Backend Management

(defun send-to-shell-get-available-backends ()
  "Return a list of available shell backends."
  (let ((backends (list 'eshell 'shell)))
    (when (featurep 'vterm)
      (push 'vterm backends))
    (when (featurep 'eat)
      (push 'eat backends))
    (when (featurep 'ghostel)
      (push 'ghostel backends))
    (nreverse backends)))

(defun send-to-shell-get-shell-buffer-name ()
  "Get the shell buffer name for the current buffer."
  (format "*%s*" (buffer-name)))

;;; Backend-Specific Implementations

(defun send-to-shell--send-to-eshell (start end shell-buf-name)
  "Send region to eshell buffer."
  (let ((text (buffer-substring start end)))
    (with-current-buffer (get-buffer-create shell-buf-name)
      (unless (eq major-mode 'eshell-mode)
        (eshell))
      (goto-char (point-max))
      (insert text)
      (eshell-send-input))))

(defun send-to-shell--send-to-shell (start end shell-buf-name)
  "Send region to shell buffer."
  (let ((text (buffer-substring start end)))
    (with-current-buffer (get-buffer-create shell-buf-name)
      (unless (eq major-mode 'shell-mode)
        (ignore-errors (shell)))
      (ignore-errors
        (comint-send-string shell-buf-name (concat text "\n"))))))

(defun send-to-shell--send-via-comint (start end shell-buf-name init-fn)
  "Send region to buffer via comint, initializing with INIT-FN if needed."
  (let ((text (buffer-substring start end)))
    (unless (get-buffer shell-buf-name)
      (funcall init-fn)
      (rename-buffer shell-buf-name))
    (comint-send-string shell-buf-name text)
    (comint-send-string shell-buf-name "\n")))

(defun send-to-shell--send-to-vterm (start end shell-buf-name)
  "Send region to vterm buffer."
  (when (featurep 'vterm)
    (send-to-shell--send-via-comint start end shell-buf-name
                                      (lambda () (vterm-other-window)))
    (sleep-for 0 send-to-shell-vterm-sleep-ms)))

(defun send-to-shell--send-to-eat (start end shell-buf-name)
  "Send region to eat buffer."
  (when (featurep 'eat)
    (send-to-shell--send-via-comint start end shell-buf-name #'eat)))

(defun send-to-shell--send-to-ghostel (start end shell-buf-name)
  "Send region to ghostel buffer."
  (when (featurep 'ghostel)
    (send-to-shell--send-via-comint start end shell-buf-name #'ghostel)))

;;; Core Functions

(defun send-to-shell-send-region (start end backend)
  "Send region to shell buffer using specified BACKEND.
START and END define the region to send."
  (let ((shell-buf-name (send-to-shell-get-shell-buffer-name)))
    (pcase backend
      ('eshell (send-to-shell--send-to-eshell start end shell-buf-name))
      ('shell (send-to-shell--send-to-shell start end shell-buf-name))
      ('vterm (send-to-shell--send-to-vterm start end shell-buf-name))
      ('eat (send-to-shell--send-to-eat start end shell-buf-name))
      ('ghostel (send-to-shell--send-to-ghostel start end shell-buf-name))
      (_ (error "Unknown backend: %s" backend)))))

(defun send-to-shell-send-block (backend)
  "Send current block/paragraph to shell using BACKEND."
  (let ((old-point (point)))
    (mark-paragraph)
    (send-to-shell-send-region (region-beginning) (region-end) backend)
    (goto-char old-point)))

(defun send-to-shell-send-region-or-block (backend)
  "Send selected region or current block to shell using BACKEND.
If a region is active, send it. Otherwise send the current block."
  (if (region-active-p)
      (let ((old-point (point)))
        (send-to-shell-send-region (region-beginning) (region-end) backend)
        (goto-char old-point))
    (send-to-shell-send-block backend)))

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

(defun send-to-shell-start-shell (backend)
  "Start a shell buffer for the current buffer using BACKEND."
  (interactive (list send-to-shell-default-backend))
  (let ((shell-buf-name (send-to-shell-get-shell-buffer-name)))
    (pcase backend
      ('eshell
       (send-to-shell--start-buffer-with-mode shell-buf-name 'eshell-mode #'eshell))
      ('shell
       (send-to-shell--start-buffer-with-mode
        shell-buf-name 'shell-mode (lambda () (ignore-errors (shell)))))
      ('vterm
       (send-to-shell--start-buffer-if-missing
        shell-buf-name 'vterm #'vterm-other-window))
      ('eat
       (send-to-shell--start-buffer-if-missing shell-buf-name 'eat #'eat))
      ('ghostel
       (send-to-shell--start-buffer-if-missing
        shell-buf-name 'ghostel #'ghostel))
      (_ (error "Unknown backend: %s" backend)))))

(defun send-to-shell--transient-set-backend (backend)
  "Set `send-to-shell-default-backend' to BACKEND."
  (setq send-to-shell-default-backend backend)
  (message "send-to-shell backend set to %s" backend))

(defun send-to-shell--transient-select-backend ()
  "Prompt for a backend and set it as the transient default."
  (interactive)
  (send-to-shell--transient-set-backend (send-to-shell--select-backend)))

(defun send-to-shell--transient-start-shell ()
  "Start a shell for `send-to-shell-default-backend'."
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

(defvar send-to-shell--transient-prefix-command nil
  "Internal transient prefix command for `send-to-shell'.")

(transient-define-prefix send-to-shell-transient-menu ()
  "Transient menu for send-to-shell."
  [["Backend"
    ("b" "Switch backend" send-to-shell--transient-select-backend)
    ("s" "Start shell" send-to-shell--transient-start-shell)
    ("d" "Send region or block" send-to-shell--transient-send-region-or-block)]])

(defun send-to-shell ()
  "Main entry point for send-to-shell package.
Shows an interactive menu (if transient available) or prompts for backend selection."
  (interactive)
  (if (require 'transient nil t)
      (send-to-shell--transient-dispatcher)
    (send-to-shell--fallback-menu)))

(defun send-to-shell--fallback-menu ()
  "Fallback menu when transient is not available."
  (let* ((backend (send-to-shell--select-backend))
         (action (send-to-shell--select-action)))
    (send-to-shell--perform-action action backend)))

(defun send-to-shell--select-backend ()
  "Prompt user to select a shell backend."
  (let* ((backends (send-to-shell-get-available-backends))
         (backend-names (mapcar #'symbol-name backends)))
    (intern (completing-read "Select shell backend: " backend-names
                            nil t (symbol-name send-to-shell-default-backend)))))

(defun send-to-shell--select-action ()
  "Prompt user to select an action."
  (let ((actions '(("Send region" . region)
                   ("Send block" . block)
                   ("Send region or block" . region-or-block))))
    (cdr (assoc (completing-read "Select action: " (mapcar #'car actions) nil t)
               actions))))

(defun send-to-shell--perform-action (action backend)
  "Perform the selected ACTION using the specified BACKEND."
  (pcase action
    ('region (send-to-shell-send-region (region-beginning) (region-end) backend))
    ('block (send-to-shell-send-block backend))
    ('region-or-block (send-to-shell-send-region-or-block backend))
    (_ (message "Unknown action: %s" action))))

(defun send-to-shell--transient-dispatcher ()
  "Dispatcher for the transient menu."
  (send-to-shell-transient-menu))

(provide 'send-to-shell)
;;; send-to-shell.el ends here
