;;; init.el -*- lexical-binding: t; -*-
;;
;; Port of April's Neovim configuration (%LOCALAPPDATA%\nvim).
;;
;; Deliberate omissions, mirroring the source config's README: no file tree, no
;; debugger, no test runner, no Git porcelain, no AI completion. :lang org is
;; off too -- nothing in the Neovim config corresponds to it, and it is the
;; largest package group Doom ships.
;;
;; The README also leaves out a terminal; this config has one because April
;; asked for terminal splits. It is ghostel: vterm and term need a Unix pty,
;; while ghostel drives Windows' ConPTY.
;;
;; Not ported, by choice: Curse's mouse gestures, and the pinned diagnostic
;; preview (lsp-ui's sideline stands in for it).

(doom! :completion
       (vertico +icons)             ; mini.pick + mini.extra
       (corfu +orderless +icons)    ; blink.cmp

       :ui
       doom                         ; theme infrastructure; Groselha lands here
       dashboard                    ; mini.starter
       hl-todo
       modeline                     ; lualine
       ophints
       (popup +defaults)
       smooth-scroll                ; neoscroll.nvim
       tabs                         ; bufferline.nvim

       :editor
       (evil +everywhere)
       fold
       (format +onsave)             ; BufWritePre formatting
       snippets
       (whitespace +guess +trim)    ; the BufWritePre whitespace strip

       :emacs
       dired
       electric
       undo                         ; opt.undofile
       vc

       :term
       ghostel                      ; :terminal, for the terminal splits

       :checkers
       (syntax +icons)              ; vim.diagnostic

       :tools
       (eval +overlay)
       lookup                       ; gd / gr
       (lsp +peek)                  ; nvim-lspconfig
       tree-sitter                  ; nvim-treesitter
       editorconfig                 ; vim.g.editorconfig

       :lang
       (cc   +lsp +tree-sitter)     ; clangd
       (rust +lsp +tree-sitter)     ; rust-analyzer
       (lua  +lsp +tree-sitter)     ; lua-language-server
       (zig  +lsp +tree-sitter)     ; zls
       emacs-lisp                   ; you will be editing this config
       markdown
       sh

       :config
       (default +bindings +smartparens))  ; mini.pairs
