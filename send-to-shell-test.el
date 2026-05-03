;;; send-to-shell-test.el --- Tests for send-to-shell package

(require 'cl-lib)
(require 'ert)
(require 'send-to-shell)

;;; Test suite for transient menu and backend selection

(ert-deftest send-to-shell-test-backend-unavailable-eshell ()
  "Test that eshell backend is no longer available."
  (should-not (member 'eshell (send-to-shell-get-available-backends))))

(ert-deftest send-to-shell-test-backend-available-shell ()
  "Test that shell backend is available."
  (should (member 'shell (send-to-shell-get-available-backends))))

(ert-deftest send-to-shell-test-backend-available-vterm ()
  "Test that vterm backend is available if installed."
  (let ((backends (send-to-shell-get-available-backends)))
    (if (featurep 'vterm)
        (should (member 'vterm backends))
      (should (not (member 'vterm backends))))))

(ert-deftest send-to-shell-test-backend-available-eat ()
  "Test that eat backend is available if installed."
  (let ((backends (send-to-shell-get-available-backends)))
    (if (featurep 'eat)
        (should (member 'eat backends))
      (should (not (member 'eat backends))))))

(ert-deftest send-to-shell-test-backend-available-ghostel ()
  "Test that ghostel backend is available if installed."
  (let ((backends (send-to-shell-get-available-backends)))
    (if (featurep 'ghostel)
        (should (member 'ghostel backends))
      (should (not (member 'ghostel backends))))))

(ert-deftest send-to-shell-test-get-shell-buffer-name ()
  "Test that shell buffer name is correctly formatted."
  (with-temp-buffer
    (rename-buffer "test-buffer")
    (should (equal (send-to-shell-get-shell-buffer-name)
                   "*test-buffer*"))))

(ert-deftest send-to-shell-test-send-region-to-unknown-backend ()
  "Test sending region to an unknown backend fails."
  (with-temp-buffer
    (insert "echo hello")
    (let ((start (point-min))
          (end (point-max)))
      (should-error (send-to-shell-send-region start end 'eshell)))))

(ert-deftest send-to-shell-test-send-region-to-shell ()
  "Test sending region to shell backend."
  (with-temp-buffer
    (insert "echo hello")
    (let ((start (point-min))
          (end (point-max)))
      ;; Verify the function executes without error
      (send-to-shell-send-region start end 'shell))))

(ert-deftest send-to-shell-test-send-region-to-vterm ()
  "Test sending region to vterm backend when available."
  (when (featurep 'vterm)
    (with-temp-buffer
      (insert "echo hello")
      (let ((start (point-min))
            (end (point-max)))
        ;; Verify the function executes without error
        (send-to-shell-send-region start end 'vterm)))))

(ert-deftest send-to-shell-test-send-block ()
  "Test sending block (paragraph) to shell."
  (with-temp-buffer
    (insert "echo hello\n\necho world")
    (goto-char (point-min))
    ;; Verify the function executes without error
    (send-to-shell-send-block 'shell)))

(ert-deftest send-to-shell-test-send-block-moves-point ()
  "Test that send-block preserves point position."
  (with-temp-buffer
    (insert "echo hello\n\necho world")
    (goto-char 6)
    (let ((old-point (point)))
      (send-to-shell-send-block 'shell)
      (should (equal (point) old-point)))))

(ert-deftest send-to-shell-test-send-region-or-block-with-region ()
  "Test send-region-or-block uses region when available."
  (with-temp-buffer
    (insert "echo hello\necho world")
    (set-mark (point-min))
    (goto-char (+ (point-min) 5))
    (let ((old-point (point)))
      (send-to-shell-send-region-or-block 'shell)
      (should (equal (point) old-point)))))

(ert-deftest send-to-shell-test-send-region-or-block-no-region ()
  "Test send-region-or-block sends block when no region."
  (with-temp-buffer
    (insert "echo hello\n\necho world")
    (goto-char 6)
    (deactivate-mark)
    (let ((old-point (point)))
      (send-to-shell-send-region-or-block 'shell)
      (should (equal (point) old-point)))))

(ert-deftest send-to-shell-test-transient-menu-requires-transient ()
  "Test that transient menu dispatcher is callable."
  ;; Just verify the function exists and is callable
  (should (functionp 'send-to-shell))
  (should (functionp 'send-to-shell--fallback-menu))
  (should (functionp 'send-to-shell--select-backend))
  (should (functionp 'send-to-shell--select-action)))

(ert-deftest send-to-shell-test-transient-menu-switches-default-backend ()
  "Test that transient backend selection updates the default backend."
  (let ((send-to-shell-default-backend 'shell))
    (send-to-shell--transient-set-backend 'shell)
    (should (eq send-to-shell-default-backend 'shell))))

(ert-deftest send-to-shell-test-select-backend-does-not-prefill-default-value ()
  "Test that backend selection shows choices without a default value."
  (let ((captured-initial-input :unset))
    (cl-letf (((symbol-function 'completing-read)
               (lambda (_prompt _collection _predicate require-match
                        &optional initial-input _hist _def _inherit)
                 (setq captured-initial-input initial-input)
                 (should require-match)
                 "shell")))
      (should (eq (send-to-shell--select-backend) 'shell))
      (should (null captured-initial-input)))))

(ert-deftest send-to-shell-test-transient-menu-starts-shell-for-current-backend ()
  "Test that transient start-shell uses the selected backend."
  (let ((send-to-shell-default-backend 'shell)
        (called-backend nil))
    (cl-letf (((symbol-function 'send-to-shell-start-shell)
               (lambda (backend)
                 (setq called-backend backend))))
      (send-to-shell--transient-start-shell)
      (should (eq called-backend 'shell)))))

(ert-deftest send-to-shell-test-transient-menu-sends-region-or-block-for-current-backend ()
  "Test that transient send action uses the selected backend."
  (let ((send-to-shell-default-backend 'shell)
        (called-backend nil))
    (cl-letf (((symbol-function 'send-to-shell-send-region-or-block)
               (lambda (backend)
                 (setq called-backend backend))))
      (send-to-shell--transient-send-region-or-block)
      (should (eq called-backend 'shell)))))

(ert-deftest send-to-shell-test-transient-dispatcher-invokes-transient-menu ()
  "Test that the transient dispatcher invokes the transient menu."
  (let ((menu-called nil))
    (cl-letf (((symbol-function 'send-to-shell-transient-menu)
               (lambda ()
                 (setq menu-called t))))
      (send-to-shell--transient-dispatcher)
      (should menu-called))))

(ert-deftest send-to-shell-test-start-shell-opens-shell-in-other-window ()
  "Test that starting a shell keeps the source buffer visible."
  (save-window-excursion
    (delete-other-windows)
    (let* ((source-buffer (generate-new-buffer "send-to-shell-source"))
           (shell-buffer-name "*send-to-shell-source*"))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) source-buffer)
            (with-current-buffer source-buffer
              (sh-mode)
              (cl-letf (((symbol-function 'send-to-shell--start-buffer-with-mode)
                         (lambda (buffer-name mode _init-fn)
                           (with-current-buffer (get-buffer-create buffer-name)
                             (setq major-mode mode)))))
                (send-to-shell-start-shell 'shell)
                (should (= (count-windows) 2))
                (should (eq (window-buffer (selected-window)) source-buffer))
                (should (get-buffer-window shell-buffer-name))
                (should-not (eq (selected-window)
                                (get-buffer-window shell-buffer-name))))))
        (when (get-buffer shell-buffer-name)
          (kill-buffer shell-buffer-name))
        (kill-buffer source-buffer)))))

(ert-deftest send-to-shell-test-start-shell-requires-sh-mode ()
  "Test that starting a shell requires `sh-mode'."
  (with-temp-buffer
    (let ((start-called nil))
      (fundamental-mode)
      (cl-letf (((symbol-function 'send-to-shell--start-buffer-with-mode-in-other-window)
                 (lambda (&rest _args)
                   (setq start-called t))))
        (should-error (send-to-shell-start-shell 'shell) :type 'user-error)
        (should-not start-called)))))

(ert-deftest send-to-shell-test-start-shell-names-shell-buffer-after-source-buffer ()
  "Test that starting a shell uses the source buffer name."
  (save-window-excursion
    (let ((source-buffer (generate-new-buffer "test.sh")))
      (unwind-protect
        (progn
            (switch-to-buffer source-buffer)
            (sh-mode)
            (send-to-shell-start-shell 'shell)
            (should (get-buffer "*test.sh*"))
            (should-not (get-buffer "*shell*")))
        (when (get-buffer "*test.sh*")
          (let ((process (get-buffer-process "*test.sh*")))
            (when process
              (set-process-query-on-exit-flag process nil)))
          (kill-buffer "*test.sh*"))
        (when (get-buffer "*shell*")
          (let ((process (get-buffer-process "*shell*")))
            (when process
              (set-process-query-on-exit-flag process nil)))
          (kill-buffer "*shell*"))
        (kill-buffer source-buffer)))))

(provide 'send-to-shell-test)
;;; send-to-shell-test.el ends here
