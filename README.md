```
███████╗███╗   ███╗ █████╗  ██████╗███████╗       █████╗ ██╗    ██╗██╗  ██╗
██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝      ██╔══██╗██║    ██║██║ ██╔╝
█████╗  ██╔████╔██║███████║██║     ███████╗█████╗███████║██║ █╗ ██║█████╔╝
██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║╚════╝██╔══██║██║███╗██║██╔═██╗
███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║      ██║  ██║╚███╔███╔╝██║  ██╗
╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝      ╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝  ╚═╝
```

[![CI](https://github.com/MenkeTechnologies/emacs-awk/actions/workflows/ci.yml/badge.svg)](https://github.com/MenkeTechnologies/emacs-awk/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-05d9e8.svg)](https://menketechnologies.github.io/emacs-awk/)
[![Report](https://img.shields.io/badge/report-ff2a6d.svg)](https://menketechnologies.github.io/emacs-awk/report.html)
[![Emacs](https://img.shields.io/badge/emacs-27.1%2B-39ff14.svg)](https://www.gnu.org/software/emacs/)
[![License: MIT](https://img.shields.io/badge/License-MIT-d300c5.svg)](https://opensource.org/licenses/MIT)

### `[EMACS MAJOR MODE // NEON FONT-LOCK // FIELD RECORDS // RUN + LSP]`

> *"Open a `.awk`. Records, fields, and the whole pattern/action engine light up."*

Emacs major mode (`awkrs-mode`) for **AWK**, targeting the **[awkrs](https://github.com/MenkeTechnologies/awkrs)** Rust AWK implementation. Font-lock for keywords, built-in variables, built-in functions, field references, and `/regex/` literals; filetype detection; brace-aware indentation; run a buffer through `awkrs`; eldoc + completion for builtins; and LSP via `awkrs --lsp` (eglot + lsp-mode). Named `awkrs-mode` so it does not clash with Emacs' built-in `awk-mode`.

### [`Read the Docs`](https://menketechnologies.github.io/emacs-awk/) &middot; [`Engineering Report`](https://menketechnologies.github.io/emacs-awk/report.html) · [`awkrs`](https://github.com/MenkeTechnologies/awkrs) · [`vim-awk`](https://github.com/MenkeTechnologies/vim-awk) · [`vscode-awk`](https://github.com/MenkeTechnologies/vscode-awk)

---

## [0x00] OVERVIEW

**emacs-awk** is the Emacs major mode for **AWK** (the `awkrs` engine). It provides:

- **Filetype detection** — `*.awk` files (`auto-mode-alist`) and awk / awkrs shebangs (`interpreter-mode-alist`).
- **Syntax highlighting** — font-lock for AWK keywords, the built-in variables, the built-in functions, field references (`$0` `$1` `$NF`), `/regex/` literals, `#` comments, strings, and numbers.
- **Indentation** — brace-aware `indent-line-function`.
- **Run** — `awkrs-run-buffer` (`C-c C-c`) runs the buffer's program through `awkrs` via `compile`.
- **eldoc + completion** — one-line signatures and `completion-at-point` for AWK builtin functions.
- **Language server** — `awkrs --lsp` via **eglot** (built in since Emacs 29) and **lsp-mode**.

AWK's builtin surface is small and fixed by the language spec, so the keyword / variable / function lists are plain `regexp-opt` lists in `awkrs-mode.el` — no generated hash-table stdlib is needed (that machinery only exists in the sibling `emacs-stryke` because stryke's builtin set overflows Emacs' regexp compiler). Builtin-function signatures for eldoc / completion live in `awkrs-stdlib.el`, authored from the POSIX awk spec and the gawk extensions awkrs accepts.

`awkrs --lsp` is launched with **only** `--lsp` — an appended `--stdio` is rejected by the binary, so neither client is configured to add one.

Created by **[MenkeTechnologies](https://github.com/MenkeTechnologies)**.

---

## [0x01] FEATURE MATRIX

| Capability | Status |
|---|---|
| Filetype detection — `*.awk` | **Implemented** — `auto-mode-alist` |
| Filetype detection — shebang | **Implemented** — `interpreter-mode-alist` (`awk`, `awkrs`) |
| Syntax highlighting | **Implemented** — font-lock for keywords, built-in vars/funcs, fields, regex |
| Comments | **Implemented** — `#` line comments via syntax table |
| Strings | **Implemented** — double-quoted via syntax table |
| `/regex/` literals | **Implemented** — `syntax-propertize` (operand position only) |
| Indentation | **Implemented** — brace-aware `awkrs-indent-line` |
| Run buffer | **Implemented** — `awkrs-run-buffer` (`C-c C-c`) via `compile` |
| eldoc | **Implemented** — builtin-function signatures |
| Completion | **Implemented** — `completion-at-point` over builtin functions |
| Language server (eglot) | **Implemented** — `awkrs --lsp` |
| Language server (lsp-mode) | **Implemented** — registered client |
| Config | `awkrs-executable`, `awkrs-indent-offset` |

> The `awkrs` binary must be on `$PATH` to run buffers and for the language server. Build **[awkrs](https://github.com/MenkeTechnologies/awkrs)** (`cargo install --path .`).

---

## [0x02] INSTALL

### Manual

```elisp
;; clone, then:
(add-to-list 'load-path "/path/to/emacs-awk")
(require 'awkrs-mode)
```

### use-package + built-in VC

```elisp
(use-package awkrs-mode
  :mode "\\.awk\\'"
  :vc (:url "https://github.com/MenkeTechnologies/emacs-awk"))
```

Open any `.awk` file — it lights up. Press `C-c C-c` to run it through `awkrs`. With eglot, run `M-x eglot` to start the language server (or `(add-hook 'awkrs-mode-hook #'eglot-ensure)`).

---

## [0x03] SYNTAX // FACES

| Token group | Face |
|---|---|
| Keywords (`BEGIN` `END` `function` `if` `for` `while` `print` `getline`) | `font-lock-keyword-face` |
| Built-in variables (`NR` `NF` `FS` `OFS` `RS` `SUBSEP` `ARGV` `ENVIRON`) | `awkrs-builtin-var-face` |
| Built-in functions (`length` `substr` `gsub` `sprintf` `split` `system`) | `font-lock-builtin-face` |
| Field references (`$0` `$1` `$NF`) | `awkrs-field-ref-face` |
| User function names | `font-lock-function-name-face` |
| Strings / comments / `/regex/` | via syntax table + `syntax-propertize` |

---

## [0x04] RUN

`awkrs-run-buffer` (bound to `C-c C-c`) runs the current buffer's program through `awkrs -f FILE` using Emacs' `compile`, so output, errors, and `next-error` navigation land in the `*compilation*` buffer. The executable is `awkrs-executable` (default `"awkrs"`).

---

## [0x05] LANGUAGE SERVER

`awkrs-mode` registers `awkrs --lsp` for both clients (lazily, so neither is a hard dependency):

- **eglot** (Emacs 29+): `M-x eglot` in a `.awk` buffer.
- **lsp-mode**: `M-x lsp`.

The executable is `awkrs-executable` (default `"awkrs"`); change it for a custom path. The server is launched with `--lsp` only — no `--stdio` is appended (the binary rejects it).

---

## [0x06] LAYOUT

```
emacs-awk/
├── awkrs-mode.el           # major mode: syntax table, font-lock, indent, run, LSP, eldoc, completion
├── awkrs-stdlib.el         # builtin-function signatures (eldoc + completion)
├── scripts/face-test.el    # fontifies a sample and asserts faces
├── tests/face-test.sh      # byte-compile + face assertions wrapper
└── tests/*.sh              # README / docs / workflow validators
```

---

## [0x07] LICENSE

MIT © **[MenkeTechnologies](https://github.com/MenkeTechnologies)**
