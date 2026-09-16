;;; groselha-faces.el --- Groselha for Doom Emacs -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; Port of lua/groselha/{init,highlights}.lua from the Neovim config. Faces
;; follow highlights.lua section by section, each beside the Neovim group it
;; stands in for.
;;
;; RULE: a token is either a tone rung (t1..t4) or groselha. Bold is spent on
;; the hazard family alone; weight is simulated by lightness.
;;
;; Tree-sitter captures and semantic tokens use the faces lisp/ts-queries.el
;; and lisp/lsp-semantic.el name after Neovim's groups: @keyword.type is
;; `ts.keyword.type', @lsp.mod.unsafe is `ts.lsp.mod.unsafe'.

(require 'cl-lib)
(require 'doom-themes)
(require 'groselha-palettes
         (expand-file-name "groselha-palettes"
                           (file-name-directory (or load-file-name buffer-file-name))))

(defgroup groselha-theme nil
  "Groselha colour scheme."
  :group 'faces)

(defcustom groselha-italic-comments t
  "Set comments in italic."
  :type 'boolean
  :group 'groselha-theme)

(defcustom groselha-bold-unsafe t
  "Spend bold on hazards: unsafe, exceptions, the panic family.
It is the one place Groselha uses bold."
  :type 'boolean
  :group 'groselha-theme)

(defun groselha--defs (palette)
  "`def-doom-theme' colour bindings for PALETTE."
  (append
   (cl-loop for (key value) on palette by #'cddr
            when (and (stringp value) (string-prefix-p "#" value))
            collect `(,(intern (substring (symbol-name key) 1)) '(,value ,value nil)))
   ;; Doom's shared slots, filled from the ladder, so the faces doom-themes
   ;; sets on its own stay on it too.
   '((bg-alt gutter) (fg t3) (fg-alt t4)
     (base0 border) (base1 gutter) (base2 chrome) (base3 line) (base4 sel)
     (base5 ghost) (base6 t4) (base7 t2) (base8 t1)
     (grey t4)
     (red gro) (orange gro) (yellow gro) (magenta gro)
     (green t2) (teal t2) (blue t2) (dark-blue t2) (violet t2) (cyan t2) (dark-cyan t3)
     (highlight gro) (vertical-bar border) (selection sel) (region sel)
     (builtin t1) (comments t4) (doc-comments t4) (constants gro) (functions t2)
     (keywords t1) (methods t2) (operators t3) (type gro) (strings gro)
     (variables t3) (numbers gro)
     (error gro) (warning gro) (success t3)
     (vc-modified t4) (vc-added t2) (vc-deleted gro))))

(defun groselha--faces ()
  "Face overrides for `def-doom-theme', following highlights.lua."
  (let ((KW   '(:foreground t1))                                  ; keywords
        (NAME '(:foreground t2))                                  ; functions
        (BODY '(:foreground t3))                                  ; everything flat
        (CM   '(:foreground t4 :slant (if groselha-italic-comments 'italic 'normal)))
        (META '(:foreground t2 :slant 'italic))                   ; attributes
        (VAL  '(:foreground gro))                                 ; values and types
        (STAT '(:foreground gro :slant 'italic))                  ; statics
        (HAZ  '(:foreground gro :weight (if groselha-bold-unsafe 'bold 'normal))))
    `(;;;; UI
      (default :background bg :foreground t3)                    ; Normal
      (cursor :background t1)                                     ; Cursor
      (hl-line :background line)                                  ; CursorLine
      (line-number :foreground ghost :background bg)              ; LineNr
      (line-number-current-line :foreground gro :background line) ; CursorLineNr, cursorlineopt number,line
      (fringe :foreground ghost :background bg)                   ; SignColumn, FoldColumn
      (region :background sel :extend t)                          ; Visual
      (secondary-selection :background line :extend t)
      (isearch :foreground bg :background gro)                    ; IncSearch
      (isearch-fail :foreground gro)
      (lazy-highlight :foreground bg :background gro)             ; Search
      (match :foreground bg :background gro)
      (query-replace :foreground bg :background gro)              ; Substitute
      (show-paren-match :foreground gro :background 'unspecified :underline t :weight 'normal) ; MatchParen
      (show-paren-mismatch :foreground bg :background gro)
      (shadow :foreground t4)                                     ; Conceal
      (escape-glyph :foreground gro)
      (nobreak-space :foreground ghost :underline t)
      (whitespace-space :foreground ghost)                        ; Whitespace
      (whitespace-tab :foreground ghost)
      (whitespace-newline :foreground ghost)
      (vertical-border :foreground border :background border)     ; WinSeparator
      (window-divider :foreground border)
      (window-divider-first-pixel :foreground border)
      (window-divider-last-pixel :foreground border)
      (mode-line :foreground t2 :background chrome :box nil)      ; StatusLine
      (mode-line-inactive :foreground t4 :background gutter :box nil) ; StatusLineNC
      (mode-line-emphasis :foreground t1)
      (mode-line-highlight :foreground t1 :background sel)
      (header-line :foreground t2 :background bg)                 ; WinBar
      (tab-bar :foreground t4 :background chrome)                 ; TabLineFill
      (tab-bar-tab :foreground t1 :background float)              ; TabLineSel
      (tab-bar-tab-inactive :foreground t4 :background gutter)    ; TabLine
      (minibuffer-prompt :foreground t2)                          ; ModeMsg
      (link :foreground gro :underline t :weight 'normal)         ; @string.special.url
      (link-visited :foreground t2 :underline t)
      (highlight :foreground t1 :background sel)
      (tooltip :foreground t3 :background float)                  ; NormalFloat
      (error :foreground gro)                                     ; ErrorMsg, DiagnosticError
      (warning :foreground gro :slant 'italic)                    ; DiagnosticWarn
      (success :foreground t3)                                    ; OkMsg, DiagnosticOk
      (help-key-binding :foreground gro :background line :box nil)
      (hl-todo :foreground bg :background gro :weight 'normal)    ; Todo
      (solaire-default-face :inherit 'default :background bg)
      (solaire-hl-line-face :background line)

      ;;;; completion
      (corfu-default :foreground t3 :background float)            ; Pmenu
      (corfu-current :foreground t1 :background sel)              ; PmenuSel
      (corfu-bar :background t4)                                  ; PmenuThumb
      (corfu-border :background border)                           ; FloatBorder
      (corfu-annotations :foreground t4)
      (corfu-popupinfo :foreground t3 :background float)
      ;; nvim's own default for these is bold; the accent says it just as well
      (completions-common-part :foreground gro)                   ; PmenuMatch
      (completions-first-difference :foreground t1)
      (completions-annotations :foreground t4)
      (orderless-match-face-0 :foreground gro :weight 'normal)
      (orderless-match-face-1 :foreground gro :weight 'normal)
      (orderless-match-face-2 :foreground gro :weight 'normal)
      (orderless-match-face-3 :foreground gro :weight 'normal)
      (vertico-current :foreground t1 :background sel :extend t)  ; PmenuSel
      (marginalia-documentation :foreground t4 :slant 'italic)

      ;;;; which-key
      (which-key-key-face :foreground gro)                        ; WhichKey
      (which-key-group-description-face :foreground t2)           ; WhichKeyGroup
      (which-key-command-description-face :foreground t3)         ; WhichKeyDesc
      (which-key-local-map-description-face :foreground t3)
      (which-key-separator-face :foreground t4)                   ; WhichKeySeparator
      (which-key-note-face :foreground t4)

      ;;;; centaur-tabs, standing in for bufferline
      (centaur-tabs-default :foreground t4 :background chrome)    ; BufferLineFill
      (centaur-tabs-unselected :foreground t4 :background gutter) ; TabLine
      (centaur-tabs-selected :foreground t1 :background float)    ; TabLineSel
      (centaur-tabs-unselected-modified :foreground t4 :background gutter)
      (centaur-tabs-selected-modified :foreground t1 :background float)
      (centaur-tabs-modified-marker-unselected :foreground gro :background gutter)
      (centaur-tabs-modified-marker-selected :foreground gro :background float)
      (centaur-tabs-close-unselected :foreground t4 :background gutter)
      (centaur-tabs-close-selected :foreground t4 :background float)
      (centaur-tabs-active-bar-face :background gro)

      ;;;; doom
      (doom-modeline-bar :background gro)
      (doom-modeline-bar-inactive :background gutter)
      (doom-modeline-buffer-modified :foreground gro)
      (doom-dashboard-banner :foreground t4)
      (doom-dashboard-loaded :foreground t4)
      (doom-dashboard-menu-title :foreground t2)
      (doom-dashboard-menu-desc :foreground gro)

      ;;;; diagnostics: only two hues exist, so severity rides on tone and line
      (flycheck-error :underline (list :style 'wave :color gro))  ; DiagnosticUnderlineError
      (flycheck-warning :underline (list :style 'line :color gro)) ; DiagnosticUnderlineWarn
      (flycheck-info :underline (list :style 'line :color t4))    ; DiagnosticUnderlineInfo
      (flycheck-fringe-error :foreground gro)
      (flycheck-fringe-warning :foreground gro)
      (flycheck-fringe-info :foreground t3)
      (flycheck-error-list-error :foreground gro)
      (flycheck-error-list-warning :foreground gro :slant 'italic)
      (flycheck-error-list-info :foreground t3)

      ;;;; lsp
      (lsp-face-highlight-textual :foreground 'unspecified :background sel :weight 'normal) ; LspReferenceText
      (lsp-face-highlight-read :foreground 'unspecified :background sel :weight 'normal)    ; LspReferenceRead
      (lsp-face-highlight-write :foreground 'unspecified :background sel :underline t :weight 'normal) ; LspReferenceWrite
      (lsp-inlay-hint-face :foreground t4 :background line :slant 'italic) ; LspInlayHint
      (lsp-lens-face :foreground t4 :slant 'italic)               ; LspCodeLens

      ;;;; diff
      (diff-added :foreground t2 :background line)                ; DiffAdd
      (diff-changed :foreground 'unspecified :background line)    ; DiffChange
      (diff-removed :foreground gro :background line)             ; DiffDelete
      (diff-refine-added :foreground t2 :background sel)
      (diff-refine-changed :foreground gro :background sel)       ; DiffText
      (diff-refine-removed :foreground gro :background sel)
      (diff-indicator-added :foreground t2)                       ; diffAdded
      (diff-indicator-changed :foreground t3)                     ; diffChanged
      (diff-indicator-removed :foreground gro)                    ; diffRemoved
      (diff-file-header :foreground t2)                           ; diffFile
      (diff-hunk-header :foreground t4)                           ; diffLine

      ;;;; terminal, as init.lua's terminal()
      (ansi-color-black :foreground bg :background bg)
      (ansi-color-red :foreground gro :background gro)
      (ansi-color-green :foreground t2 :background t2)
      (ansi-color-yellow :foreground gro :background gro)
      (ansi-color-blue :foreground t2 :background t2)
      (ansi-color-magenta :foreground gro :background gro)
      (ansi-color-cyan :foreground t2 :background t2)
      (ansi-color-white :foreground t3 :background t3)
      (ansi-color-bright-black :foreground t4 :background t4)
      (ansi-color-bright-red :foreground gro :background gro)
      (ansi-color-bright-green :foreground t1 :background t1)
      (ansi-color-bright-yellow :foreground gro :background gro)
      (ansi-color-bright-blue :foreground t1 :background t1)
      (ansi-color-bright-magenta :foreground gro :background gro)
      (ansi-color-bright-cyan :foreground t1 :background t1)
      (ansi-color-bright-white :foreground t1 :background t1)

      ;;;; legacy syntax
      (font-lock-comment-face ,@CM)                               ; Comment
      (font-lock-comment-delimiter-face ,@CM)
      (font-lock-doc-face ,@CM)
      (font-lock-doc-markup-face :foreground t2 :slant 'italic)   ; SpecialComment
      (font-lock-string-face ,@VAL)                               ; String
      (font-lock-constant-face ,@VAL)                             ; Constant
      (font-lock-number-face ,@VAL)                               ; Number
      (font-lock-escape-face ,@VAL)                               ; SpecialChar
      (font-lock-regexp-face ,@VAL)
      (font-lock-regexp-grouping-backslash ,@VAL)
      (font-lock-regexp-grouping-construct ,@VAL)
      (font-lock-keyword-face ,@KW)                               ; Keyword, Statement
      (font-lock-builtin-face ,@KW)
      (font-lock-function-name-face ,@NAME)                       ; Function
      (font-lock-function-call-face ,@NAME)
      (font-lock-variable-name-face ,@BODY)                       ; Identifier
      (font-lock-variable-use-face ,@BODY)
      (font-lock-property-name-face ,@BODY)
      (font-lock-property-use-face ,@BODY)
      (font-lock-type-face ,@VAL)                                 ; Type
      (font-lock-preprocessor-face ,@META)                        ; PreProc
      (font-lock-operator-face ,@BODY)                            ; Operator
      (font-lock-negation-char-face ,@BODY)
      (font-lock-punctuation-face ,@BODY)                         ; Delimiter
      (font-lock-bracket-face ,@BODY)
      (font-lock-delimiter-face ,@BODY)
      (font-lock-misc-punctuation-face ,@BODY)
      (font-lock-warning-face :foreground gro)                    ; Error

      ;;;; tree-sitter captures, in :h treesitter-highlight-groups order
      ;; identifiers: one flat rung, so an expression reads as a single phrase
      (ts.variable ,@BODY)
      (ts.variable.builtin ,@KW)                                  ; self / this
      (ts.variable.parameter ,@BODY)
      (ts.variable.parameter.builtin ,@BODY)                      ; `...', `it': parameters, not words
      (ts.variable.member ,@BODY)
      (ts.constant ,@VAL)
      (ts.constant.builtin ,@VAL)
      (ts.constant.macro ,@VAL)
      (ts.module ,@BODY)
      (ts.module.builtin ,@BODY)
      (ts.label ,@BODY)
      ;; literals
      (ts.string ,@VAL)
      (ts.string.documentation ,@CM)
      (ts.string.regexp ,@VAL)
      (ts.string.escape ,@VAL)
      (ts.string.special ,@VAL)
      (ts.string.special.symbol ,@VAL)
      (ts.string.special.path ,@VAL)
      (ts.string.special.url :foreground gro :underline t)
      (ts.character ,@VAL)
      (ts.character.special ,@VAL)
      (ts.boolean ,@VAL)
      (ts.number ,@VAL)
      (ts.number.float ,@VAL)
      ;; types: the accent marks what a thing *is*, not only what it carries
      (ts.type ,@VAL)
      (ts.type.builtin ,@VAL)
      (ts.type.definition ,@VAL)
      (ts.attribute ,@META)
      (ts.attribute.builtin ,@META)
      (ts.property ,@BODY)
      ;; functions
      (ts.function ,@NAME)
      (ts.function.builtin ,@NAME)
      (ts.function.call ,@NAME)
      (ts.function.macro ,@NAME)
      (ts.function.method ,@NAME)
      (ts.function.method.call ,@NAME)
      (ts.constructor ,@VAL)                                      ; a constructor names a type
      (ts.operator ,@BODY)
      ;; keywords
      (ts.keyword ,@KW)
      (ts.keyword.coroutine ,@KW)
      (ts.keyword.function ,@KW)
      (ts.keyword.operator ,@KW)
      (ts.keyword.import ,@KW)
      (ts.keyword.type ,@VAL)                                     ; struct / enum / class / trait
      (ts.keyword.modifier ,@KW)
      (ts.keyword.repeat ,@KW)
      (ts.keyword.return ,@KW)
      (ts.keyword.debug ,@VAL)                                    ; a leftover dbg! is worth a stop
      (ts.keyword.exception ,@HAZ)
      (ts.keyword.conditional ,@KW)
      (ts.keyword.conditional.ternary ,@BODY)                     ; `?:' is an operator, not a word
      (ts.keyword.directive ,@META)
      (ts.keyword.directive.define ,@META)
      (ts.punctuation.delimiter ,@BODY)
      (ts.punctuation.bracket ,@BODY)
      (ts.punctuation.special ,@BODY)
      (ts.comment ,@CM)
      (ts.comment.documentation ,@CM)
      (ts.comment.error :foreground bg :background gro)
      (ts.comment.warning :foreground gro)
      (ts.comment.todo :foreground bg :background gro)
      (ts.comment.note :foreground t2 :slant 'italic)
      ;; doc comments inject markup; emphasis is a tone rung here, as everywhere
      (ts.markup.strong :foreground t2)
      (ts.markup.italic :foreground t3 :slant 'italic)
      (ts.markup.strikethrough :foreground t4 :strike-through t)
      (ts.markup.underline :foreground t3 :underline t)
      (ts.markup.heading :foreground t2)
      (ts.markup.heading.1 :foreground t1)
      (ts.markup.heading.2 :foreground t2)
      (ts.markup.heading.3 :foreground t2)
      (ts.markup.heading.4 :foreground t3)
      (ts.markup.heading.5 :foreground t3)
      (ts.markup.heading.6 :foreground t3)
      (ts.markup.quote ,@CM)
      (ts.markup.math ,@VAL)
      (ts.markup.link :foreground t4 :underline t)
      (ts.markup.link.label :foreground t3)
      (ts.markup.link.url :foreground t4 :underline t)
      (ts.markup.raw :foreground t3)
      (ts.markup.raw.block :foreground t3)
      (ts.markup.list ,@BODY)
      (ts.markup.list.checked :foreground t4)
      (ts.markup.list.unchecked ,@BODY)
      (ts.diff.plus :foreground t2)
      (ts.diff.minus :foreground gro)
      (ts.diff.delta :foreground t3)
      (ts.tag ,@NAME)
      (ts.tag.builtin ,@NAME)
      (ts.tag.attribute ,@BODY)
      (ts.tag.delimiter ,@BODY)
      ;; Groselha's own captures, emitted only by the after/queries
      (ts.keyword.unsafe ,@HAZ)
      (ts.keyword.contract :foreground t1 :weight 'bold)          ; bold, but on the keyword rung
      ;; per language: the same capture can mean different things
      (ts.character.special.rust ,@BODY)                          ; `_', `..', glob `*': patterns, not values
      (ts.keyword.import.c ,@META)                                ; `#include' is preprocessor, not `use'
      (ts.keyword.import.cpp ,@META)
      (ts.constructor.lua ,@BODY)                                 ; the braces of a table constructor

      ;;;; LSP semantic tokens: what a name resolves to
      (ts.lsp.type.namespace ,@BODY)
      (ts.lsp.type.type ,@VAL)
      (ts.lsp.type.class ,@VAL)
      (ts.lsp.type.struct ,@VAL)
      (ts.lsp.type.union ,@VAL)
      (ts.lsp.type.enum ,@VAL)
      (ts.lsp.type.interface ,@VAL)
      (ts.lsp.type.concept ,@VAL)
      (ts.lsp.type.typeAlias ,@VAL)
      (ts.lsp.type.typeParameter ,@VAL)
      (ts.lsp.type.function ,@NAME)
      (ts.lsp.type.method ,@NAME)
      (ts.lsp.type.parameter ,@BODY)
      (ts.lsp.type.variable ,@BODY)
      (ts.lsp.type.property ,@BODY)
      (ts.lsp.type.enumMember ,@VAL)
      (ts.lsp.type.constParameter ,@VAL)
      ;; rust-analyzer has token types where clangd uses modifiers
      (ts.lsp.type.static ,@STAT)
      (ts.lsp.type.const ,@VAL)
      (ts.lsp.type.invalidEscapeSequence :foreground gro :underline (list :style 'wave :color gro))
      (ts.lsp.type.comment ,@CM)                                  ; clangd reports inactive #if regions as comments
      ;; what is true of it; overlapping modifiers merge rather than race
      (ts.lsp.typemod.variable.constant ,@VAL)
      (ts.lsp.typemod.variable.readonly ,@VAL)
      (ts.lsp.typemod.variable.defaultLibrary ,@VAL)
      (ts.lsp.typemod.variable.static ,@STAT)
      (ts.lsp.typemod.variable.global ,@STAT)
      (ts.lsp.typemod.variable.fileScope ,@STAT)
      (ts.lsp.typemod.variable.globalScope ,@STAT)
      (ts.lsp.typemod.parameter.readonly ,@BODY)                  ; `const std::string&' is still an argument
      (ts.lsp.typemod.parameter.constant ,@BODY)
      (ts.lsp.mod.unsafe ,@HAZ)                                   ; every token rust-analyzer marks unsafe
      ;; lisp/curse.el: its reports' names are Special
      (curse-echo ,@VAL))))

(defmacro groselha-define-theme (name variant docstring)
  "Define the Groselha theme NAME from the palette VARIANT."
  (let ((palette (alist-get variant groselha-palettes)))
    (unless palette (error "No Groselha palette named %s" variant))
    `(def-doom-theme ,name ,docstring
       :family 'groselha
       :background-mode ',(if (plist-get palette :dark) 'dark 'light)
       ,(groselha--defs palette)
       ,(groselha--faces)
       ;; init.lua's ink_declared_names; see lisp/lsp-semantic.el
       ((ts-lsp-ink-declarations t)))))

(provide 'groselha-faces)
