(ert-deftest elpy-company-backend-should-be-interactive ()
  (elpy-testcase ()
    (require 'company)

    (mletf* ((called-backend nil)
             (company-begin-backend (backend) (setq called-backend backend)))

      (call-interactively 'elpy-company-backend)

      (should (eq called-backend 'elpy-company-backend)))))

(ert-deftest elpy-company-backend-should-find-no-prefix-without-elpy ()
  (elpy-testcase ()
    (elpy-module-company 'global-init)
    (should-not (elpy-company-backend 'prefix))))

(ert-deftest elpy-company-backend-should-find-no-prefix-in-string ()
  (elpy-testcase ()
    (elpy-modules-run 'global-init)
    (python-mode)
    (elpy-mode)
    (insert "# hello")
    (should-not (elpy-company-backend 'prefix))))

(ert-deftest elpy-company-backend-should-find-simple-prefix-string ()
  (elpy-testcase ()
    (elpy-modules-run 'global-init)
    (python-mode)
    (elpy-mode)
    (insert "hello")
    (should (equal (elpy-company-backend 'prefix)
                   "hello"))))

(ert-deftest elpy-company-backend-should-find-full-prefix-string ()
  (elpy-testcase ()
    (elpy-modules-run 'global-init)
    (python-mode)
    (elpy-mode)
    (insert "hello.world")
    (should (equal (elpy-company-backend 'prefix)
                   '("world" . t)))))

(ert-deftest elpy-company-backend-should-never-require-match ()
  (elpy-testcase ()
    (should (equal (elpy-company-backend 'require-match)
                   'never))))

;; FIXME! candidates is a convoluted *mess*.

(ert-deftest elpy-company-backend-should-get-cached-meta ()
  (elpy-testcase ()
    (mletf* ((called-with nil)
             (elpy-company--cache-meta (arg)
                                       (setq called-with arg)
                                       "bar"))

      (should (equal "bar"
                     (elpy-company-backend 'meta "foo")))
      (should (equal "foo" called-with)))))

(ert-deftest elpy-company-backend-should-trim-long-meta ()
  (elpy-testcase ()
    (mletf* ((called-with nil)
             (elpy-company--cache-meta (arg)
                                       (setq called-with arg)
                                       "foo\nbar\nbaz\nqux"))

      (should (equal "foo\nbar"
                     (elpy-company-backend 'meta "foo")))
      (should (equal "foo" called-with)))))

(ert-deftest elpy-company-backend-should-get-cached-annotation ()
  (elpy-testcase ()
    (mletf* ((called-with nil)
             (elpy-company--cache-annotation (arg)
                                             (setq called-with arg)
                                             "bar"))

      (should (equal "bar"
                     (elpy-company-backend 'annotation "foo")))
      (should (equal "foo" called-with)))))

(ert-deftest elpy-company-backend-should-get-cached-docs ()
  (elpy-testcase ()
    (mletf* ((called-with-origname nil)
             (elpy-company--cache-name (arg)
                                       (setq called-with-origname arg)
                                       "backend-name")
             (called-with-backendname nil)
             (elpy-rpc-get-completion-docstring (arg)
                                                (setq called-with-backendname
                                                      arg)
                                                "docstring")
             (called-with-doc nil)
             (company-doc-buffer (doc)
                                 (setq called-with-doc doc)))

      (elpy-company-backend 'doc-buffer "orig-name")

      (should (equal called-with-origname "orig-name"))
      (should (equal called-with-backendname "backend-name"))
      (should (equal called-with-doc "docstring")))))

(ert-deftest elpy-company-backend-should-get-cached-location ()
  (elpy-testcase ()
    (mletf* ((called-with-origname nil)
             (elpy-company--cache-name (arg)
                                       (setq called-with-origname arg)
                                       "backend-name")
             (called-with-backendname nil)
             (elpy-rpc-get-completion-location (arg)
                                               (setq called-with-backendname
                                                     arg)
                                               '("file" 23)))

      (should (equal '("file" . 23)
                     (elpy-company-backend 'location "orig-name")))
      (should (equal called-with-origname "orig-name"))
      (should (equal called-with-backendname "backend-name")))))

(ert-deftest elpy-company-backend-should-add-shell-candidates ()
  (elpy-testcase ()
    (elpy-modules-run 'global-init)
    (python-mode)
    (elpy-mode)
    (let ((elpy-get-info-from-shell t)
          (elpy-get-info-from-shell-timeout 10))
      (insert "variable_script = 3\n")
      (insert "def function_script(a): print(a)\n")
      (elpy-shell-get-or-create-process)
      (python-shell-send-string "variable_shell = 4")
      (python-shell-send-string "def function_shell(a):\n   print(a)")
      ;; Test variable completions
      (insert "variable")
      (let* ((cand (elpy-rpc-get-completions))
             (ext-cand (elpy-company--add-interpreter-completions-candidates cand)))
        (should (string= (mapconcat (lambda (cand) (cdr (assoc 'name cand)))
                                    cand " ")
                         "variable_script"))
        (should (string= (mapconcat (lambda (cand) (cdr (assoc 'name cand)))
                                    ext-cand " ")
                         "variable_shell variable_script")))
      ;; Test function completions
      (insert "\nfunction")
      (sleep-for 0.1)
      (let* ((cand (elpy-rpc-get-completions))
             (ext-cand (elpy-company--add-interpreter-completions-candidates cand)))
        (should (string= (mapconcat (lambda (cand) (cdr (assoc 'name cand)))
                                    cand " ")
                         "function_script"))
        (should (string= (mapconcat (lambda (cand) (cdr (assoc 'name cand)))
                                    ext-cand " ")
                         "function_shell function_script"))))))

(ert-deftest elpy-company-backend-should-not-add-shell-candidates ()
  (elpy-testcase ()
    (elpy-modules-run 'global-init)
    (python-mode)
    (elpy-mode)
    (insert "variable_script = 3\n")
    (insert "def function_script(a): print(a)\n")
    (elpy-shell-get-or-create-process)
    (python-shell-send-string "variable_shell = 4")
    (python-shell-send-string "def function_shell(a):\n   print(a)")
    ;; Test variable completions
    (insert "variable")
    (let* ((elpy-get-info-from-shell nil)
           (cand (elpy-rpc-get-completions))
           (ext-cand (elpy-company--add-interpreter-completions-candidates cand)))
      (should (string= (mapconcat (lambda (cand) (cdr (assoc 'name cand)))
                                  cand " ")
                       (mapconcat (lambda (cand) (cdr (assoc 'name cand)))
                                  ext-cand " "))))))
