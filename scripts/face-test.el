;;; face-test.el --- Assert awkrs-mode font-lock faces -*- lexical-binding: t; -*-

;; Loads awkrs-mode, fontifies a sample, and asserts the face applied at the
;; first occurrence of each probe token. Run:
;;   emacs --batch -L . -l scripts/face-test.el

;;; Code:

(require 'awkrs-mode)

(defvar awkrs-face-test--sample
  (concat
   "#!/usr/bin/env awk -f\n"
   "BEGIN { FS = \",\"; total = 0 }\n"
   "/^#/ { next }\n"
   "$1 ~ /error/ {\n"
   "    line = $0;\n"
   "    n = length(line);\n"
   "    total += substr($2, 1, 3);\n"
   "    printf \"%d\\n\", NR;\n"
   "}\n"
   "function summarize(arr,    i) {\n"
   "    for (i in arr) print toupper(i);\n"
   "}\n"
   "END { print total, NF }\n"
   "# a trailing comment\n"))

(defun awkrs-face-test--face-of (token)
  "Return the face text-property at the start of the first whole-symbol TOKEN.
Case-sensitive and symbol-bounded so e.g. \"in\" does not match \"line\"."
  (goto-char (point-min))
  (let ((case-fold-search nil))
    (if (re-search-forward (concat "\\_<" (regexp-quote token) "\\_>") nil t)
        (let ((face (get-text-property (match-beginning 0) 'face)))
          (if (listp face) (car face) face))
      'NOT-FOUND)))

(let ((checks
       '(("BEGIN"     . font-lock-keyword-face)
         ("END"       . font-lock-keyword-face)
         ("function"  . font-lock-keyword-face)
         ("for"       . font-lock-keyword-face)
         ("next"      . font-lock-keyword-face)
         ("print"     . font-lock-keyword-face)
         ("printf"    . font-lock-keyword-face)
         ("FS"        . awkrs-builtin-var-face)
         ("NR"        . awkrs-builtin-var-face)
         ("NF"        . awkrs-builtin-var-face)
         ("length"    . font-lock-builtin-face)
         ("substr"    . font-lock-builtin-face)
         ("toupper"   . font-lock-builtin-face)
         ("summarize" . font-lock-function-name-face)))
      (failed 0))
  (with-temp-buffer
    (insert awkrs-face-test--sample)
    (awkrs-mode)
    (font-lock-ensure)
    ;; quoted string + comment via syntax table
    (let* ((str-face (awkrs-face-test--face-of "error"))   ; inside /error/? no:
           ;; "error" first appears inside the /error/ regex; probe a string
           ;; instead via the printf format below.
           (com-face (awkrs-face-test--face-of "trailing")))
      (ignore str-face)
      (dolist (probe checks)
        (let* ((token (car probe))
               (want (cdr probe))
               (got (awkrs-face-test--face-of token))
               (ok (eq got want)))
          (unless ok (setq failed (1+ failed)))
          (princ (format "%s  %-12s want=%-26s got=%s\n"
                         (if ok "PASS" "FAIL") token want got))))
      ;; A double-quoted string: probe the literal comma between quotes.
      (goto-char (point-min))
      (let ((str-ok nil))
        (when (re-search-forward "\"," nil t)
          (setq str-ok (eq (let ((f (get-text-property (match-beginning 0) 'face)))
                             (if (listp f) (car f) f))
                           'font-lock-string-face)))
        (unless str-ok (setq failed (1+ failed)))
        (princ (format "%s  %-12s want=%-26s\n"
                       (if str-ok "PASS" "FAIL") "<string>" 'font-lock-string-face)))
      (let ((ok (eq com-face 'font-lock-comment-face)))
        (unless ok (setq failed (1+ failed)))
        (princ (format "%s  %-12s want=%-26s got=%s\n"
                       (if ok "PASS" "FAIL") "<comment>" 'font-lock-comment-face com-face)))))
  (princ (if (zerop failed) "\nALL FACE CHECKS PASSED\n" (format "\n%d CHECK(S) FAILED\n" failed)))
  (kill-emacs (if (zerop failed) 0 1)))

;;; face-test.el ends here
