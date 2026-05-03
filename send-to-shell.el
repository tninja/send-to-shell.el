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

(defun send-to-shell-transient-menu ()
  "Show transient menu for shell operations.
This function requires transient package."
  ;; TODO: Implement transient menu in a future version
  (message "Transient menu not yet implemented"))

(provide 'send-to-shell)
;;; send-to-shell.el ends here
