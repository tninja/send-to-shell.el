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
  "Test that eat backend is available when installed or loaded."
  (cl-letf (((symbol-function 'featurep)
             (lambda (feature)
               (not (eq feature 'eat))))
            ((symbol-function 'locate-library)
             (lambda (library)
               (when (equal library "eat")
                 "/tmp/eat.el"))))
    (should (member 'eat (send-to-shell-get-available-backends)))))

(ert-deftest send-to-shell-test-backend-unavailable-eat-without-library ()
  "Test that eat backend is hidden when unavailable."
  (cl-letf (((symbol-function 'featurep)
             (lambda (feature)
               (not (eq feature 'eat))))
            ((symbol-function 'locate-library)
             (lambda (library)
               (unless (equal library "eat")
                 "/tmp/other.el"))))
    (should-not (member 'eat (send-to-shell-get-available-backends)))))

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

(ert-deftest send-to-shell-test-send-region-to-shell-errors-without-shell ()
  "Test sending region to shell backend errors when shell is missing."
  (with-temp-buffer
    (insert "echo hello")
    (let ((start (point-min))
          (end (point-max)))
      (should-error (send-to-shell-send-region start end 'shell)
                    :type 'user-error))))

(ert-deftest send-to-shell-test-send-region-to-vterm ()
  "Test sending region to vterm backend errors when shell is missing."
  (when (featurep 'vterm)
    (with-temp-buffer
      (insert "echo hello")
      (let ((start (point-min))
            (end (point-max)))
        (should-error (send-to-shell-send-region start end 'vterm)
                      :type 'user-error)))))

(ert-deftest send-to-shell-test-send-block-errors-without-shell ()
  "Test sending block errors when shell is missing."
  (with-temp-buffer
    (insert "echo hello\n\necho world")
    (goto-char (point-min))
    (should-error (send-to-shell-send-block 'shell) :type 'user-error)))

(ert-deftest send-to-shell-test-send-block-moves-point ()
  "Test that send-block preserves point position."
  (with-temp-buffer
    (insert "echo hello\n\necho world")
    (goto-char 6)
    (let ((old-point (point)))
      (cl-letf (((symbol-function 'send-to-shell-send-region)
                 (lambda (&rest _args) nil)))
        (send-to-shell-send-block 'shell)
        (should (equal (point) old-point))))))

(ert-deftest send-to-shell-test-send-region-or-block-with-region ()
  "Test send-region-or-block uses region when available."
  (with-temp-buffer
    (insert "echo hello\necho world")
    (set-mark (point-min))
    (goto-char (+ (point-min) 5))
    (let ((old-point (point))
          (called nil))
      (cl-letf (((symbol-function 'send-to-shell-send-region)
                 (lambda (&rest _args)
                   (setq called t))))
        (send-to-shell-send-region-or-block 'shell)
        (should called)
        (should (equal (point) old-point))))))

(ert-deftest send-to-shell-test-send-region-or-block-no-region ()
  "Test send-region-or-block sends block when no region."
  (with-temp-buffer
    (insert "echo hello\n\necho world")
    (goto-char 6)
    (deactivate-mark)
    (let ((old-point (point))
          (called nil))
      (cl-letf (((symbol-function 'send-to-shell-send-block)
                 (lambda (&rest _args)
                   (setq called t))))
        (send-to-shell-send-region-or-block 'shell)
        (should called)
        (should (equal (point) old-point))))))

(ert-deftest send-to-shell-test-send-current-line-errors-without-shell ()
  "Test sending current line errors when shell is missing."
  (with-temp-buffer
    (insert "echo hello\necho world")
    (goto-char 6)
    (should-error (send-to-shell-send-current-line 'shell) :type 'user-error)))

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

(ert-deftest send-to-shell-test-transient-menu-describes-current-backend ()
  "Test that transient menu describes the currently selected backend."
  (let ((send-to-shell-default-backend 'eat))
    (should (equal (send-to-shell--select-backend-description)
                   "Switch backend (eat)"))))

(ert-deftest send-to-shell-test-transient-menu-labels-backend-action-dynamically ()
  "Test that transient menu uses a dynamic description for backend selection."
  (let ((suffix (transient-get-suffix 'send-to-shell-transient-menu "b")))
    (should suffix)
    (should (eq (plist-get (nth 2 suffix) :command)
                'send-to-shell--transient-select-backend))
    (should (eq (plist-get (nth 2 suffix) :description)
                'send-to-shell--select-backend-description))))

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

(ert-deftest send-to-shell-test-transient-menu-starts-or-switches-shell-for-current-backend ()
  "Test that transient start-or-switch-shell uses the selected backend."
  (let ((send-to-shell-default-backend 'shell)
        (called-backend nil))
    (cl-letf (((symbol-function 'send-to-shell-start-shell)
               (lambda (backend)
                 (setq called-backend backend))))
      (send-to-shell--transient-start-or-switch-shell)
      (should (eq called-backend 'shell)))))

(ert-deftest send-to-shell-test-transient-menu-labels-shell-action-as-start-or-switch ()
  "Test that transient menu labels the shell action as start or switch."
  (let ((suffix (transient-get-suffix 'send-to-shell-transient-menu "s")))
    (should suffix)
    (should (equal (plist-get (nth 2 suffix) :description)
                   "Start or switch to shell"))
    (should (eq (plist-get (nth 2 suffix) :command)
                'send-to-shell--transient-start-or-switch-shell))))

(ert-deftest send-to-shell-test-transient-menu-sends-current-line-for-current-backend ()
  "Test that transient current-line action uses the selected backend."
  (let ((send-to-shell-default-backend 'shell)
        (called-backend nil))
    (cl-letf (((symbol-function 'send-to-shell-send-current-line)
               (lambda (backend)
                 (setq called-backend backend))))
      (send-to-shell--transient-send-current-line)
      (should (eq called-backend 'shell)))))

(ert-deftest send-to-shell-test-transient-menu-labels-current-line-action ()
  "Test that transient menu exposes the current-line action."
  (let ((suffix (transient-get-suffix 'send-to-shell-transient-menu "l")))
    (should suffix)
    (should (equal (plist-get (nth 2 suffix) :description)
                   "Send current line"))
    (should (eq (plist-get (nth 2 suffix) :command)
                'send-to-shell--transient-send-current-line))))

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

(ert-deftest send-to-shell-test-start-shell-opens-eat-in-other-window-when-installed ()
  "Test that starting eat loads it and keeps the source buffer visible."
  (save-window-excursion
    (delete-other-windows)
    (let* ((source-buffer (generate-new-buffer "eat-source.sh"))
           (shell-buffer-name "*eat-source.sh*")
           (eat-loaded nil)
           (require-called nil))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) source-buffer)
            (with-current-buffer source-buffer
              (sh-mode)
              (cl-letf (((symbol-function 'featurep)
                         (lambda (feature)
                           (if (eq feature 'eat)
                               eat-loaded
                             nil)))
                        ((symbol-function 'locate-library)
                         (lambda (library)
                           (when (equal library "eat")
                             "/tmp/eat.el")))
                        ((symbol-function 'require)
                         (lambda (feature &optional _filename _noerror)
                           (when (eq feature 'eat)
                             (setq require-called t
                                   eat-loaded t))
                           feature))
                        ((symbol-function 'eat)
                         (lambda ()
                           (switch-to-buffer (get-buffer-create shell-buffer-name))
                           (setq major-mode 'eat-mode))))
                (send-to-shell-start-shell 'eat)
                (should require-called)
                (should (= (count-windows) 2))
                (should (eq (window-buffer (selected-window)) source-buffer))
                (should (get-buffer-window shell-buffer-name))
                (should-not (eq (selected-window)
                                (get-buffer-window shell-buffer-name))))))
        (when (get-buffer shell-buffer-name)
          (kill-buffer shell-buffer-name))
        (kill-buffer source-buffer)))))

(ert-deftest send-to-shell-test-start-shell-renames-eat-buffer-to-source-buffer-name ()
  "Test that starting eat renames its default buffer to match the source buffer."
  (save-window-excursion
    (delete-other-windows)
    (let ((source-buffer (generate-new-buffer "test.sh"))
          (eat-loaded nil)
          (require-called nil))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) source-buffer)
            (with-current-buffer source-buffer
              (sh-mode)
              (cl-letf (((symbol-function 'featurep)
                         (lambda (feature)
                           (if (eq feature 'eat)
                               eat-loaded
                             nil)))
                        ((symbol-function 'locate-library)
                         (lambda (library)
                           (when (equal library "eat")
                             "/tmp/eat.el")))
                        ((symbol-function 'require)
                         (lambda (feature &optional _filename _noerror)
                           (when (eq feature 'eat)
                             (setq require-called t
                                   eat-loaded t))
                           feature))
                        ((symbol-function 'eat)
                         (lambda ()
                           (let ((eat-buffer (get-buffer-create "*eat*")))
                             (with-current-buffer eat-buffer
                               (setq major-mode 'eat-mode))
                             (set-window-buffer (selected-window) eat-buffer)))))
                (send-to-shell-start-shell 'eat)
                (should require-called)
                (should (get-buffer "*test.sh*"))
                (should-not (get-buffer "*eat*"))
                (should (eq (window-buffer (selected-window)) source-buffer))
                (should (get-buffer-window "*test.sh*"))
                (with-current-buffer "*test.sh*"
                  (should (eq major-mode 'eat-mode))))))
        (when (get-buffer "*eat*")
          (kill-buffer "*eat*"))
        (when (get-buffer "*test.sh*")
          (kill-buffer "*test.sh*"))
        (kill-buffer source-buffer)))))

(ert-deftest send-to-shell-test-start-shell-opens-ghostel-in-other-window ()
  "Test that starting ghostel keeps the source buffer visible."
  (save-window-excursion
    (delete-other-windows)
    (let* ((source-buffer (generate-new-buffer "ghostel-source.sh"))
           (shell-buffer-name "*ghostel-source.sh*")
           (ghostel-buffer-name "*ghostel*")
           (orig-featurep (symbol-function 'featurep)))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) source-buffer)
            (with-current-buffer source-buffer
              (sh-mode)
              (cl-letf (((symbol-function 'featurep)
                         (lambda (feature)
                           (if (eq feature 'ghostel)
                               t
                             (funcall orig-featurep feature))))
                        ((symbol-function 'ghostel)
                         (lambda ()
                           (switch-to-buffer (get-buffer-create ghostel-buffer-name))
                           (setq major-mode 'ghostel-mode))))
                (send-to-shell-start-shell 'ghostel)
                (should (= (count-windows) 2))
                (should (eq (window-buffer (selected-window)) source-buffer))
                (should (get-buffer-window shell-buffer-name))
                (should-not (eq (selected-window)
                                (get-buffer-window shell-buffer-name))))))
        (when (get-buffer shell-buffer-name)
          (kill-buffer shell-buffer-name))
        (when (get-buffer "*ghostel*")
          (kill-buffer "*ghostel*"))
        (kill-buffer source-buffer))))

(ert-deftest send-to-shell-test-send-region-to-ghostel-errors-without-shell ()
  "Test that sending to ghostel errors when shell is missing."
  (save-window-excursion
    (delete-other-windows)
    (let* ((source-buffer (generate-new-buffer "ghostel-send.sh"))
           (shell-buffer-name "*ghostel-send.sh*")
           (ghostel-buffer-name "*ghostel*")
           (orig-featurep (symbol-function 'featurep)))
      (unwind-protect
          (progn
            (set-window-buffer (selected-window) source-buffer)
            (with-current-buffer source-buffer
              (insert "echo hello")
              (sh-mode)
              (cl-letf (((symbol-function 'featurep)
                         (lambda (feature)
                           (if (eq feature 'ghostel)
                               t
                             (funcall orig-featurep feature))))
                        ((symbol-function 'ghostel)
                         (lambda ()
                           (switch-to-buffer (get-buffer-create ghostel-buffer-name))
                           (setq major-mode 'ghostel-mode)))
                        ((symbol-function 'comint-send-string)
                         (lambda (&rest _args) nil)))
                (should-error (send-to-shell-send-region (point-min) (point-max) 'ghostel)
                              :type 'user-error)
                (should (= (count-windows) 1))
                (should (eq (window-buffer (selected-window)) source-buffer))
                (should-not (get-buffer shell-buffer-name))
                (should-not (get-buffer ghostel-buffer-name))))))
        (when (get-buffer shell-buffer-name)
          (kill-buffer shell-buffer-name))
        (when (get-buffer "*ghostel*")
          (kill-buffer "*ghostel*"))
        (kill-buffer source-buffer)))))

(provide 'send-to-shell-test)
;;; send-to-shell-test.el ends here
