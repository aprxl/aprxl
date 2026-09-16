;;; groselha-breu-theme.el --- Groselha Breu (dark), ported from the Neovim colorscheme. -*- lexical-binding: t; no-byte-compile: t; -*-

;; Found through the theme search path, not `load-file-name': a theme not yet marked
;; safe is evaluated with `eval-buffer', where `load-file-name' is nil.
(require 'groselha-faces (locate-file "groselha-faces" (custom-theme--load-path) '(".el")))

(groselha-define-theme groselha-breu breu "Groselha Breu (dark), ported from the Neovim colorscheme.")
