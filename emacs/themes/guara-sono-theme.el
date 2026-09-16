;;; guara-sono-theme.el --- Guara Sono (dark), ported from the Neovim colorscheme. -*- lexical-binding: t; no-byte-compile: t; -*-

;; Found through the theme search path, not `load-file-name': a theme not yet marked
;; safe is evaluated with `eval-buffer', where `load-file-name' is nil.
(require 'guara-faces (locate-file "guara-faces" (custom-theme--load-path) '(".el")))

(guara-define-theme guara-sono sono "Guara Sono (dark), ported from the Neovim colorscheme.")
