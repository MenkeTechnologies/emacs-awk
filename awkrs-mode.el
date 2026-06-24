;;; awkrs-mode.el --- Major mode for the AWK language (awkrs) -*- lexical-binding: t; -*-

;; Copyright (c) 2026 MenkeTechnologies

;; Author: MenkeTechnologies
;; URL: https://github.com/MenkeTechnologies/emacs-awk
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages, awk

;; This file is not part of GNU Emacs.

;;; Commentary:

;; A major mode for AWK, targeting the `awkrs' Rust AWK implementation.
;; Named `awkrs-mode' so it does not clash with Emacs' built-in
;; `awk-mode' (CC Mode).  Provides:
;;
;;   - filetype detection for `*.awk' files and awk shebangs
;;   - syntax highlighting: keywords, built-in variables, built-in
;;     functions, field references ($0 $1 ...), /regex/, # comments,
;;     strings, numbers
;;   - brace-aware indentation
;;   - run the buffer through `awkrs' (`awkrs-run-buffer', C-c C-c)
;;   - language-server integration via `awkrs --lsp' (eglot + lsp-mode)
;;   - eldoc + completion-at-point for AWK builtin functions
;;
;; AWK's builtin surface is small and fixed (the language spec), so the
;; keyword / variable / function lists are plain `regexp-opt' lists in
;; this file — no generated hash-table stdlib is needed.  Builtin
;; function signatures used for eldoc / completion live in
;; `awkrs-stdlib.el'.

;;; Code:

(require 'awkrs-stdlib)

;; Optional integrations — referenced only inside `with-eval-after-load' blocks,
;; declared here so the byte-compiler stays quiet when they are absent.
(defvar eglot-server-programs)
(defvar lsp-language-id-configuration)
(declare-function make-lsp-client "lsp-mode")
(declare-function lsp-register-client "lsp-mode")
(declare-function lsp-stdio-connection "lsp-mode")
(declare-function lsp-activate-on "lsp-mode")

(defgroup awkrs nil
  "Major mode for the AWK language (awkrs)."
  :group 'languages
  :prefix "awkrs-")

(defcustom awkrs-executable "awkrs"
  "Path to the awkrs executable, used to run buffers and for the language server."
  :type 'string
  :group 'awkrs)

(defcustom awkrs-indent-offset 4
  "Number of spaces per indentation level in `awkrs-mode'."
  :type 'integer
  :group 'awkrs)

(defface awkrs-builtin-var-face
  '((t :inherit font-lock-builtin-face :weight bold))
  "Face for AWK built-in variables (NR, NF, FS, ...)."
  :group 'awkrs)

(defface awkrs-field-ref-face
  '((t :inherit font-lock-variable-name-face :weight bold))
  "Face for AWK field references ($0, $1, $NF, ...)."
  :group 'awkrs)

;;; Keyword categories.  AWK's surface is small, so plain `regexp-opt'
;;; lists are well under Emacs' regexp-size limit.

(defconst awkrs--keywords
  '("BEGIN" "END" "function" "func" "if" "else" "while" "for" "do"
    "break" "continue" "next" "nextfile" "exit" "return" "delete" "in"
    "getline" "print" "printf")
  "AWK keywords and statement introducers.")

(defconst awkrs--builtin-vars
  '("NR" "NF" "FS" "OFS" "ORS" "RS" "FILENAME" "FNR" "RSTART" "RLENGTH"
    "SUBSEP" "ARGC" "ARGV" "ENVIRON" "CONVFMT" "OFMT")
  "AWK built-in variables.")

(defconst awkrs--builtin-funcs
  awkrs-builtin-function-names
  "AWK built-in function names (from `awkrs-stdlib').
length substr index split sub gsub match sprintf sin cos atan2 exp log
sqrt int rand srand tolower toupper system close fflush.")

;;; Font-lock.

(defconst awkrs-font-lock-keywords
  `(;; Keywords and statement introducers.
    (,(regexp-opt awkrs--keywords 'symbols) . font-lock-keyword-face)
    ;; Built-in variables (own bold face).
    (,(regexp-opt awkrs--builtin-vars 'symbols) . 'awkrs-builtin-var-face)
    ;; Built-in functions (font-lock-builtin-face), only when called: name
    ;; immediately followed by `(' so a variable named `length' is not over-lit.
    (,(concat (regexp-opt awkrs--builtin-funcs 'symbols) "(")
     (1 font-lock-builtin-face))
    ;; Field references: $0, $1, $NF, $(expr) — the leading $ + simple operand.
    ("\\$[0-9]+\\|\\$\\(?:NF\\|NR\\)\\b\\|\\$[A-Za-z_][A-Za-z0-9_]*"
     . 'awkrs-field-ref-face)
    ;; User function definitions: `function name(' — highlight the name.
    ("\\_<func\\(?:tion\\)?\\_>[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)"
     (1 font-lock-function-name-face)))
  "Font-lock keywords for `awkrs-mode'.
Strings, comments, and numbers are handled by the syntax table and by
`prog-mode' font-lock; /regex/ literals are recognized via
`awkrs-syntax-propertize-function'.")

;;; Syntax table.

(defvar awkrs-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?# "<" st)     ; line comment start
    (modify-syntax-entry ?\n ">" st)    ; comment end
    (modify-syntax-entry ?_ "_" st)     ; symbol constituent
    (modify-syntax-entry ?\" "\"" st)   ; double-quoted string
    (modify-syntax-entry ?\\ "\\" st)   ; escape
    (modify-syntax-entry ?$ "." st)     ; field sigil as punctuation
    (modify-syntax-entry ?/ "." st)     ; regex delimiter (see propertize)
    st)
  "Syntax table for `awkrs-mode'.")

;;; /regex/ literals — only in operand position (after `~', `(', `,', `{',
;;; `=', `!', `&', `|', a keyword, or line start), so division `a / b' is
;;; not mistaken for the start of a regex.  Marked as generic string.

(defun awkrs-syntax-propertize-function (start end)
  "Apply `syntax-table' text properties for /regex/ literals between START and END.
A regex is recognized only in operand position (after `~', `(', `,', `{',
`=', `!', `&', `|', `?', `:', `;', or line start, optionally following one
of the regex-taking keywords), so division `a / b' is not misread.  Both the
opening and closing `/' are marked as generic-string delimiters (class \"|\")
so the literal is bounded; an unbalanced opener would otherwise swallow the
rest of the buffer."
  (goto-char start)
  (funcall
   (syntax-propertize-rules
    ("\\(?:^\\|[=(,{!&|~?:;]\\|\\_<\\(?:return\\|print\\|case\\)\\_>\\)[ \t]*\\(/\\)\\(?:\\\\.\\|\\[\\(?:\\\\.\\|[^]\n]\\)*\\]\\|[^/\n\\]\\)+\\(/\\)"
     (1 (let ((ppss (save-excursion (syntax-ppss (match-beginning 1)))))
          (unless (or (nth 3 ppss) (nth 4 ppss))
            (string-to-syntax "|"))))
     (2 (let ((ppss (save-excursion (syntax-ppss (match-beginning 1)))))
          (unless (or (nth 3 ppss) (nth 4 ppss))
            (string-to-syntax "|"))))))
   start end))

;;; Indentation — brace-aware, mirrors `stryke-indent-line'.

(defun awkrs-indent-line ()
  "Indent the current line for `awkrs-mode'."
  (interactive)
  (let ((indent 0)
        (offset awkrs-indent-offset))
    (save-excursion
      (beginning-of-line)
      (let ((closes-block (looking-at-p "[ \t]*[)}]")))
        (when (zerop (forward-line -1))
          (while (and (looking-at-p "[ \t]*$") (zerop (forward-line -1))))
          (setq indent (current-indentation))
          ;; A line opening a block/paren (ignoring a trailing comment)
          ;; bumps the next line one level deeper.
          (when (looking-at-p ".*[({][ \t]*\\(#.*\\)?$")
            (setq indent (+ indent offset))))
        (when closes-block
          (setq indent (max 0 (- indent offset))))))
    (if (<= (current-column) (current-indentation))
        (indent-line-to indent)
      (save-excursion (indent-line-to indent)))))

;;; Run / compile — run the current buffer's program through awkrs.

(defun awkrs-run-buffer ()
  "Run the current buffer's AWK program through `awkrs' via `compile'.
The buffer must be visiting a file; it is passed with `-f'."
  (interactive)
  (unless buffer-file-name
    (user-error "Buffer is not visiting a file; save it first"))
  (when (and (buffer-modified-p) (y-or-n-p "Save buffer before running? "))
    (save-buffer))
  (require 'compile)
  (compile (format "%s -f %s"
                   (shell-quote-argument awkrs-executable)
                   (shell-quote-argument buffer-file-name))))

(defvar awkrs-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'awkrs-run-buffer)
    map)
  "Keymap for `awkrs-mode'.")

;;; eldoc + completion for builtin functions.

(defun awkrs-eldoc-function (&rest _)
  "Return the eldoc signature for the AWK builtin at point, or nil."
  (let ((sym (thing-at-point 'symbol t)))
    (and sym (awkrs-stdlib-signature sym))))

(defun awkrs-completion-at-point ()
  "`completion-at-point-functions' entry: complete AWK builtin function names."
  (let ((bounds (bounds-of-thing-at-point 'symbol)))
    (when bounds
      (list (car bounds) (cdr bounds) awkrs-builtin-function-names
            :exclusive 'no))))

;;; LSP integration — eglot (built in since Emacs 29) and lsp-mode, both
;;; optional and configured lazily.  awkrs is launched with ONLY `--lsp'
;;; (an appended `--stdio' is rejected by the binary).

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `(awkrs-mode . (,awkrs-executable "--lsp"))))

(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-language-id-configuration '(awkrs-mode . "awk"))
  (when (fboundp 'lsp-register-client)
    (lsp-register-client
     (make-lsp-client
      :new-connection (lsp-stdio-connection
                       (lambda () (list awkrs-executable "--lsp")))
      :activation-fn (lsp-activate-on "awk")
      :server-id 'awkrs-lsp))))

;;;###autoload
(define-derived-mode awkrs-mode prog-mode "Awkrs"
  "Major mode for editing AWK source, targeting the awkrs interpreter.

\\{awkrs-mode-map}"
  :syntax-table awkrs-mode-syntax-table
  (setq-local font-lock-defaults '(awkrs-font-lock-keywords))
  (setq-local syntax-propertize-function #'awkrs-syntax-propertize-function)
  (setq-local comment-start "# ")
  (setq-local comment-start-skip "#+[ \t]*")
  (setq-local comment-end "")
  (setq-local indent-line-function #'awkrs-indent-line)
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width awkrs-indent-offset)
  (add-hook 'completion-at-point-functions #'awkrs-completion-at-point nil t)
  (if (boundp 'eldoc-documentation-functions)
      (add-hook 'eldoc-documentation-functions #'awkrs-eldoc-function nil t)
    (setq-local eldoc-documentation-function #'awkrs-eldoc-function)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.awk\\'" . awkrs-mode))

;;;###autoload
(add-to-list 'interpreter-mode-alist '("awk" . awkrs-mode))

;;;###autoload
(add-to-list 'interpreter-mode-alist '("awkrs" . awkrs-mode))

(provide 'awkrs-mode)
;;; awkrs-mode.el ends here
