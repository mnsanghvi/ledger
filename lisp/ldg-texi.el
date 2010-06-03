(defvar ledger-path "/Users/johnw/bin/ledger")
(defvar ledger-sample-doc-path "/Users/johnw/src/ledger/doc/sample.dat")
(defvar ledger-normalization-args "--args-only --columns 80")

(defun ledger-texi-write-test (name command input output &optional category)
  (let ((buf (current-buffer)))
    (with-current-buffer (find-file-noselect
			  (expand-file-name (concat name ".test") category))
      (erase-buffer)
      (let ((case-fold-search nil))
	(if (string-match "\\$LEDGER\\s-+" command)
	    (setq command (replace-match "" t t command)))
	(if (string-match " -f \\$\\([-a-z]+\\)" command)
	    (setq command (replace-match "" t t command))))
      (insert command ?\n)
      (insert "<<<" ?\n)
      (insert input)
      (insert ">>>1" ?\n)
      (insert output)
      (insert ">>>2" ?\n)
      (insert "=== 0" ?\n)
      (save-buffer)
      (unless (eq buf (current-buffer))
	(kill-buffer (current-buffer))))))

(defun ledger-texi-update-test ()
  (interactive)
  (let ((details (ledger-texi-test-details))
	(name (file-name-sans-extension
	       (file-name-nondirectory (buffer-file-name)))))
    (ledger-texi-write-test
     name (nth 0 details)
     (nth 1 details)
     (ledger-texi-invoke-command
      (ledger-texi-expand-command
       (nth 0 details)
       (ledger-texi-write-test-data name (nth 1 details)))))))

(defun ledger-texi-test-details ()
  (goto-char (point-min))
  (let ((command (buffer-substring (point) (line-end-position)))
	input output)
    (re-search-forward "^<<<")
    (let ((input-beg (1+ (match-end 0))))
      (re-search-forward "^>>>1")
      (let ((output-beg (1+ (match-end 0))))
	(setq input (buffer-substring input-beg (match-beginning 0)))
	(re-search-forward "^>>>2")
	(setq output (buffer-substring output-beg (match-beginning 0)))
	(list command input output)))))

(defun ledger-texi-expand-command (command data-file)
  (if (string-match "\\$LEDGER" command)
      (replace-match (format "%s -f \"%s\" %s" ledger-path
			     data-file ledger-normalization-args) t t command)
    (concat (format "%s -f \"%s\" %s " ledger-path
		    data-file ledger-normalization-args) command)))

(defun ledger-texi-invoke-command (command)
  (with-temp-buffer (shell-command command t (current-buffer))
    (if (= (point-min) (point-max))
	(progn
	  (push-mark nil t)
	  (message "Command '%s' yielded no result at %d" command (point))
	  (ding))
      (buffer-string))))

(defun ledger-texi-write-test-data (name input)
  (let ((path (expand-file-name name temporary-file-directory)))
    (with-current-buffer (find-file-noselect path)
      (erase-buffer)
      (insert input)
      (save-buffer))
    path))

(defun ledger-texi-update-examples ()
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (re-search-forward "^@c \\(\\(?:sm\\)?ex\\) \\(\\S-+\\): \\(.*\\)" nil t)
      (let ((section (match-string 1))
	    (example-name (match-string 2))
	    (command (match-string 3)) expanded-command
	    (data-file ledger-sample-doc-path)
	    input output)
	(goto-char (match-end 0))
	(forward-line)
	(when (looking-at "@\\(\\(?:small\\)?example\\)")
	  (let ((beg (point)))
	    (re-search-forward "^@end \\(\\(?:small\\)?example\\)")
	    (delete-region beg (1+ (point)))))

	(when (let ((case-fold-search nil))
		(string-match " -f \\$\\([-a-z]+\\)" command))
	  (let ((label (match-string 1 command)))
	    (setq command (replace-match "" t t command))
	    (save-excursion
	      (goto-char (point-min))
	      (search-forward (format "@c data: %s" label))
	      (re-search-forward "@\\(\\(?:small\\)?example\\)")
	      (forward-line)
	      (let ((beg (point)))
		(re-search-forward "@end \\(\\(?:small\\)?example\\)")
		(setq data-file (ledger-texi-write-test-data
				 (format "%s.dat" label)
				 (buffer-substring-no-properties
				  beg (match-beginning 0))))))))

	(let ((section-name (if (string= section "smex")
				"smallexample"
			      "example"))
	      (output (ledger-texi-invoke-command
		       (ledger-texi-expand-command command data-file))))
	  (insert "@" section-name ?\n output
		  "@end " section-name ?\n))

	;; Update the regression test associated with this example
	(ledger-texi-write-test example-name command input output
				"../test/manual")))))

(provide 'ldg-texi)