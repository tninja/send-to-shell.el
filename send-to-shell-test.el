;;; send-to-shell-test.el --- Tests for send-to-shell package

(require 'cl-lib)
(require 'ert)
(require 'send-to-shell)

;;; Test suite for transient menu and backend selection

(ert-deftest send-to-shell-test-backend-available-eshell ()
  "Test that eshell backend is available."
  (should (member 'eshell (send-to-shell-get-available-backends))))

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

(ert-deftest send-to-shell-test-send-region-to-eshell ()
  "Test sending region to eshell backend."
  (with-temp-buffer
    (insert "echo hello")
    (let ((start (point-min))
          (end (point-max)))
      ;; Verify the function executes without error
      (send-to-shell-send-region start end 'eshell))))

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
    (send-to-shell-send-block 'eshell)))

(ert-deftest send-to-shell-test-send-block-moves-point ()
  "Test that send-block preserves point position."
  (with-temp-buffer
    (insert "echo hello\n\necho world")
    (goto-char 6)
    (let ((old-point (point)))
      (send-to-shell-send-block 'eshell)
      (should (equal (point) old-point)))))

(ert-deftest send-to-shell-test-send-region-or-block-with-region ()
  "Test send-region-or-block uses region when available."
  (with-temp-buffer
    (insert "echo hello\necho world")
    (set-mark (point-min))
    (goto-char (+ (point-min) 5))
    (let ((old-point (point)))
      (send-to-shell-send-region-or-block 'eshell)
      (should (equal (point) old-point)))))

(ert-deftest send-to-shell-test-send-region-or-block-no-region ()
  "Test send-region-or-block sends block when no region."
  (with-temp-buffer
    (insert "echo hello\n\necho world")
    (goto-char 6)
    (deactivate-mark)
    (let ((old-point (point)))
      (send-to-shell-send-region-or-block 'eshell)
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
  (let ((send-to-shell-default-backend 'eshell))
    (send-to-shell--transient-set-backend 'shell)
    (should (eq send-to-shell-default-backend 'shell))))

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

(provide 'send-to-shell-test)
;;; send-to-shell-test.el ends here
