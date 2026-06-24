;;; awkrs-stdlib.el --- AWK builtin function signatures + docs -*- lexical-binding: t; -*-

;; Copyright (c) 2026 MenkeTechnologies

;; Author: MenkeTechnologies
;; URL: https://github.com/MenkeTechnologies/emacs-awk
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages, awk

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Builtin-function metadata for `awkrs-mode'.  Unlike stryke (whose
;; ~10,450-builtin surface is generated from the binary's own reflection
;; tables into `stryke-stdlib.el'), AWK's builtin surface is small,
;; fixed, and defined by the language spec (POSIX awk + gawk extensions
;; that awkrs accepts), so it is authored here by hand rather than
;; generated.  This table powers:
;;
;;   - `eldoc' signatures in the echo area (one-line synopsis)
;;   - `completion-at-point' over builtin function names
;;
;; The function *names* are also font-locked by `awkrs-mode' via a plain
;; `regexp-opt' (the list is well under Emacs' regexp-size limit, so no
;; hash-table matcher is needed — that machinery only exists in
;; stryke-stdlib.el because 10,450 names overflow the regexp compiler).

;;; Code:

(defconst awkrs-builtin-functions
  '(;; String functions
    ("length"  . "length([s])  — length of string s (or $0); element count of array s")
    ("substr"  . "substr(s, m[, n])  — n-char substring of s starting at position m (1-based)")
    ("index"   . "index(s, t)  — position of first occurrence of t in s, else 0")
    ("split"   . "split(s, a[, fs[, seps]])  — split s into array a on fs; returns field count")
    ("sub"     . "sub(re, repl[, target])  — replace first match of re in target (default $0); returns count")
    ("gsub"    . "gsub(re, repl[, target])  — replace all matches of re in target; returns count")
    ("match"   . "match(s, re[, arr])  — position of first match of re in s; sets RSTART/RLENGTH")
    ("sprintf" . "sprintf(fmt, expr...)  — format expr... per fmt and return the string")
    ("tolower" . "tolower(s)  — copy of s with uppercase letters lowercased")
    ("toupper" . "toupper(s)  — copy of s with lowercase letters uppercased")
    ;; Arithmetic functions
    ("sin"     . "sin(x)  — sine of x (radians)")
    ("cos"     . "cos(x)  — cosine of x (radians)")
    ("atan2"   . "atan2(y, x)  — arctangent of y/x in -pi..pi")
    ("exp"     . "exp(x)  — e raised to the power x")
    ("log"     . "log(x)  — natural logarithm of x")
    ("sqrt"    . "sqrt(x)  — square root of x")
    ("int"     . "int(x)  — x truncated toward zero")
    ("rand"    . "rand()  — pseudo-random number in [0, 1)")
    ("srand"   . "srand([x])  — seed rand(); returns previous seed (default seed = time)")
    ;; I/O and general functions
    ("system"  . "system(cmd)  — run cmd via the shell; return its exit status")
    ("close"   . "close(expr[, how])  — close the file/pipe expr; return status")
    ("fflush"  . "fflush([expr])  — flush buffers for expr (all output if omitted)"))
  "Alist of AWK builtin function name -> one-line signature/synopsis.
Authored from the POSIX awk spec and gawk extensions that awkrs accepts;
not generated (AWK's builtin surface is small and fixed, unlike stryke).")

(defconst awkrs-builtin-function-names
  (mapcar #'car awkrs-builtin-functions)
  "List of AWK builtin function names (keys of `awkrs-builtin-functions').")

(defun awkrs-stdlib-signature (name)
  "Return the one-line signature string for builtin function NAME, or nil."
  (cdr (assoc name awkrs-builtin-functions)))

(provide 'awkrs-stdlib)
;;; awkrs-stdlib.el ends here
