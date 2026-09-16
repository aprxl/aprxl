;;; guara-faces.el --- Guara for Doom Emacs -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; Port of lua/guara/{init,highlights}.lua from the Neovim config. Faces follow
;; highlights.lua section by section, each beside the Neovim group it stands
;; in for.
;;
;; Weight policy: bold in code text comes only from the palette's bold-kw and
;; bold-ty flags, which mirror FONT_TYPE in the matching JetBrains scheme -- in
;; practice the e-Paper variants, where weight is one of the few
;; differentiators a near-monochrome palette has. Elsewhere hue carries the
;; emphasis. Bold on chrome (mode line, tabs, popup selection) is not code.
;;
;; Tree-sitter captures and semantic tokens use the faces lisp/ts-queries.el
;; and lisp/lsp-semantic.el name after Neovim's groups: @function.macro is
;; `ts.function.macro'.

(require 'cl-lib)
(require 'doom-themes)
(require 'guara-palettes
         (expand-file-name "guara-palettes"
                           (file-name-directory (or load-file-name buffer-file-name))))

(defgroup guara-theme nil
  "Guara colour scheme."
  :group 'faces)

(defcustom guara-italic-comments t
  "Set comments in italic."
  :type 'boolean
  :group 'guara-theme)

(defcustom guara-italic-globals t
  "Set globals and statics in italic, as the design does."
  :type 'boolean
  :group 'guara-theme)

(defcustom guara-bold-keywords 'variant
  "Bold keywords: t, nil, or `variant' for what the variant's scheme does."
  :type '(choice (const :tag "As the variant sets it" variant) boolean)
  :group 'guara-theme)

(defcustom guara-bold-types 'variant
  "Bold types: t, nil, or `variant' for what the variant's scheme does."
  :type '(choice (const :tag "As the variant sets it" variant) boolean)
  :group 'guara-theme)

(defcustom guara-italic-annotations 'variant
  "Italic annotations and macros: t, nil, or `variant'."
  :type '(choice (const :tag "As the variant sets it" variant) boolean)
  :group 'guara-theme)

(defun guara--defs (palette)
  "`def-doom-theme' colour bindings for PALETTE.
The palette's bg-alt is the cursor-line surface and is bound as `bg-line',
since Doom's own `bg-alt' means a secondary background."
  (append
   (cl-loop for (key value) on palette by #'cddr
            when (and (stringp value) (string-prefix-p "#" value))
            collect `(,(if (eq key :bg-alt) 'bg-line (intern (substring (symbol-name key) 1)))
                      '(,value ,value nil)))
   '((bg-alt bg-dim) (fg-alt fg-dim)
     (base0 border) (base1 bg-dim) (base2 bg-float) (base3 bg-line) (base4 sel)
     (base5 gutter) (base6 comment) (base7 fg-dim) (base8 fg)
     (grey comment)
     (red error) (orange kw) (yellow anno) (green fn) (teal glob) (blue glob)
     (dark-blue glob) (magenta const) (violet num) (cyan glob) (dark-cyan glob)
     (highlight kw) (vertical-bar border) (selection sel) (region sel)
     (builtin kw) (comments comment) (doc-comments comment) (constants const)
     (functions fn) (keywords kw) (methods fn) (operators op) (type ty)
     (strings str) (variables fg) (numbers num)
     (warning warn) (success ok)
     (vc-modified change) (vc-added add) (vc-deleted delete))))

(defun guara--faces (palette)
  "Face overrides for `def-doom-theme', following highlights.lua, for PALETTE."
  (let* ((bold-kw `(if (eq guara-bold-keywords 'variant) ,(plist-get palette :bold-kw) guara-bold-keywords))
         (bold-ty `(if (eq guara-bold-types 'variant) ,(plist-get palette :bold-ty) guara-bold-types))
         (italic-an `(if (eq guara-italic-annotations 'variant)
                         ,(plist-get palette :italic-anno) guara-italic-annotations))
         (KW   `(:foreground kw :weight (if ,bold-kw 'bold 'normal)))
         (TY   `(:foreground ty :weight (if ,bold-ty 'bold 'normal)))
         (ANNO `(:foreground anno :slant (if ,italic-an 'italic 'normal)))
         (CM   '(:foreground comment :slant (if guara-italic-comments 'italic 'normal)))
         (GLOB '(:foreground glob :slant (if guara-italic-globals 'italic 'normal)))
         (term (plist-get palette :term)))
    `(;;;; editor UI
      (default :background bg :foreground fg)                     ; Normal
      (cursor :background fg)                                     ; Cursor
      (hl-line :background bg-line)                               ; CursorLine
      (line-number :foreground gutter :background bg)             ; LineNr
      (line-number-current-line :foreground kw :background bg-line :weight 'bold) ; CursorLineNr
      (fringe :foreground gutter :background bg)                  ; SignColumn, FoldColumn
      (region :background sel :extend t)                          ; Visual
      (secondary-selection :background bg-line :extend t)
      (isearch :foreground bg :background kw)                     ; IncSearch
      (isearch-fail :foreground error)
      (lazy-highlight :foreground search-fg :background search)   ; Search
      (match :foreground search-fg :background search)
      (query-replace :foreground bg :background const)            ; Substitute
      (show-paren-match :foreground kw :background sel :weight 'normal) ; MatchParen
      (show-paren-mismatch :foreground bg :background error)
      (shadow :foreground fg-dim)                                 ; Conceal
      (escape-glyph :foreground anno)
      (nobreak-space :foreground nontext :underline t)
      (whitespace-space :foreground nontext)                      ; Whitespace
      (whitespace-tab :foreground nontext)
      (whitespace-newline :foreground nontext)
      (vertical-border :foreground border :background border)     ; WinSeparator
      (window-divider :foreground border)
      (window-divider-first-pixel :foreground border)
      (window-divider-last-pixel :foreground border)
      (mode-line :foreground fg :background chrome :box nil)      ; StatusLine
      (mode-line-inactive :foreground comment :background bg-dim :box nil) ; StatusLineNC
      (mode-line-emphasis :foreground kw :weight 'bold)
      (mode-line-highlight :foreground fg :background sel)
      (header-line :foreground fg :background bg)                 ; WinBar
      (tab-bar :foreground comment :background chrome)            ; TabLineFill
      (tab-bar-tab :foreground fg :background tab :weight 'bold)  ; TabLineSel
      (tab-bar-tab-inactive :foreground comment :background tab-off) ; TabLine
      (minibuffer-prompt :foreground fn)                          ; Question
      (link :foreground glob :underline t :weight 'normal)        ; Underlined
      (link-visited :foreground glob :underline t)
      (highlight :foreground fg :background sel)
      (tooltip :foreground fg :background bg-float)               ; NormalFloat
      (error :foreground error)                                   ; DiagnosticError
      (warning :foreground warn)                                  ; DiagnosticWarn
      (success :foreground ok)                                    ; DiagnosticOk
      (help-key-binding :foreground kw :background bg-dim :box nil)
      (hl-todo :foreground bg :background anno :weight 'normal)   ; Todo
      (solaire-default-face :inherit 'default :background bg)
      (solaire-hl-line-face :background bg-line)

      ;;;; completion
      (corfu-default :foreground fg :background bg-float)         ; Pmenu
      (corfu-current :foreground fg :background sel :weight 'bold) ; PmenuSel
      (corfu-bar :background gutter)                              ; PmenuThumb
      (corfu-border :background border)                           ; FloatBorder
      (corfu-annotations :foreground comment)                     ; CmpItemMenu
      (corfu-popupinfo :foreground fg :background bg-float)
      (completions-common-part :foreground kw :weight 'bold)      ; CmpItemAbbrMatch
      (completions-first-difference :foreground fg)
      (completions-annotations :foreground comment)
      (orderless-match-face-0 :foreground kw :weight 'bold)
      (orderless-match-face-1 :foreground kw :weight 'bold)
      (orderless-match-face-2 :foreground kw :weight 'bold)
      (orderless-match-face-3 :foreground kw :weight 'bold)
      (vertico-current :background sel :extend t)                 ; TelescopeSelection
      (marginalia-documentation :foreground comment :slant 'italic)

      ;;;; which-key
      (which-key-key-face :foreground kw)                         ; WhichKey
      (which-key-group-description-face :foreground glob)         ; WhichKeyGroup
      (which-key-command-description-face :foreground fg)         ; WhichKeyDesc
      (which-key-local-map-description-face :foreground fg)
      (which-key-separator-face :foreground comment)              ; WhichKeySeparator
      (which-key-note-face :foreground comment)

      ;;;; centaur-tabs, standing in for bufferline
      (centaur-tabs-default :foreground comment :background chrome) ; BufferLineFill
      (centaur-tabs-unselected :foreground comment :background tab-off) ; TabLine
      (centaur-tabs-selected :foreground fg :background tab :weight 'bold) ; TabLineSel
      (centaur-tabs-unselected-modified :foreground comment :background tab-off)
      (centaur-tabs-selected-modified :foreground fg :background tab :weight 'bold)
      (centaur-tabs-modified-marker-unselected :foreground kw :background tab-off)
      (centaur-tabs-modified-marker-selected :foreground kw :background tab)
      (centaur-tabs-close-unselected :foreground comment :background tab-off)
      (centaur-tabs-close-selected :foreground comment :background tab)
      (centaur-tabs-active-bar-face :background kw)

      ;;;; doom
      (doom-modeline-bar :background kw)
      (doom-modeline-bar-inactive :background bg-dim)
      (doom-modeline-buffer-modified :foreground kw)
      (doom-dashboard-banner :foreground comment)
      (doom-dashboard-loaded :foreground comment)
      (doom-dashboard-menu-title :foreground fn)
      (doom-dashboard-menu-desc :foreground kw)

      ;;;; diagnostics
      ;; The error tint behind flagged code mirrors ERRORS_ATTRIBUTES BACKGROUND in
      ;; the JetBrains schemes: generous enough to spot, too desaturated to shout.
      (flycheck-error :underline (list :style 'wave :color error) :background error-bg) ; DiagnosticUnderlineError
      (flycheck-warning :underline (list :style 'wave :color warn)) ; DiagnosticUnderlineWarn
      (flycheck-info :underline (list :style 'wave :color info))  ; DiagnosticUnderlineInfo
      (flycheck-fringe-error :foreground error)
      (flycheck-fringe-warning :foreground warn)
      (flycheck-fringe-info :foreground info)
      (flycheck-error-list-error :foreground error)
      (flycheck-error-list-warning :foreground warn)
      (flycheck-error-list-info :foreground info)

      ;;;; lsp
      (lsp-face-highlight-textual :foreground 'unspecified :background sel :weight 'normal) ; LspReferenceText
      (lsp-face-highlight-read :foreground 'unspecified :background sel :weight 'normal)    ; LspReferenceRead
      (lsp-face-highlight-write :foreground 'unspecified :background sel :underline t :weight 'normal) ; LspReferenceWrite
      (lsp-inlay-hint-face :foreground comment :background bg-dim :slant 'italic) ; LspInlayHint
      (lsp-lens-face :foreground comment :slant 'italic)          ; LspCodeLens

      ;;;; diff
      (diff-added :foreground 'unspecified :background diff-add)  ; DiffAdd
      (diff-changed :foreground 'unspecified :background diff-chg) ; DiffChange
      (diff-removed :foreground delete :background diff-del)      ; DiffDelete
      (diff-refine-added :background diff-txt)                    ; DiffText
      (diff-refine-changed :background diff-txt)
      (diff-refine-removed :background diff-txt)
      (diff-indicator-added :foreground add)                      ; diffAdded
      (diff-indicator-changed :foreground change)                 ; diffChanged
      (diff-indicator-removed :foreground delete)                 ; diffRemoved
      (diff-file-header :foreground ty)                           ; diffFile
      (diff-hunk-header :foreground glob)                         ; diffLine

      ;;;; terminal ANSI 0-15, from the palette
      (ansi-color-black :foreground ,(aref term 0) :background ,(aref term 0))
      (ansi-color-red :foreground ,(aref term 1) :background ,(aref term 1))
      (ansi-color-green :foreground ,(aref term 2) :background ,(aref term 2))
      (ansi-color-yellow :foreground ,(aref term 3) :background ,(aref term 3))
      (ansi-color-blue :foreground ,(aref term 4) :background ,(aref term 4))
      (ansi-color-magenta :foreground ,(aref term 5) :background ,(aref term 5))
      (ansi-color-cyan :foreground ,(aref term 6) :background ,(aref term 6))
      (ansi-color-white :foreground ,(aref term 7) :background ,(aref term 7))
      (ansi-color-bright-black :foreground ,(aref term 8) :background ,(aref term 8))
      (ansi-color-bright-red :foreground ,(aref term 9) :background ,(aref term 9))
      (ansi-color-bright-green :foreground ,(aref term 10) :background ,(aref term 10))
      (ansi-color-bright-yellow :foreground ,(aref term 11) :background ,(aref term 11))
      (ansi-color-bright-blue :foreground ,(aref term 12) :background ,(aref term 12))
      (ansi-color-bright-magenta :foreground ,(aref term 13) :background ,(aref term 13))
      (ansi-color-bright-cyan :foreground ,(aref term 14) :background ,(aref term 14))
      (ansi-color-bright-white :foreground ,(aref term 15) :background ,(aref term 15))

      ;;;; legacy syntax
      (font-lock-comment-face ,@CM)                               ; Comment
      (font-lock-comment-delimiter-face ,@CM)
      (font-lock-doc-face ,@CM)                                   ; SpecialComment
      (font-lock-doc-markup-face ,@CM)
      (font-lock-string-face :foreground str)                     ; String
      (font-lock-constant-face :foreground const)                 ; Constant
      (font-lock-number-face :foreground num)                     ; Number
      (font-lock-escape-face :foreground anno)                    ; SpecialChar
      (font-lock-regexp-face :foreground str)
      (font-lock-regexp-grouping-backslash :foreground anno)
      (font-lock-regexp-grouping-construct :foreground anno)
      (font-lock-keyword-face ,@KW)                               ; Keyword, Statement
      (font-lock-builtin-face ,@KW)
      (font-lock-function-name-face :foreground fn)               ; Function
      (font-lock-function-call-face :foreground fn)
      (font-lock-variable-name-face :foreground fg)               ; Identifier
      (font-lock-variable-use-face :foreground fg)
      (font-lock-property-name-face :foreground field)
      (font-lock-property-use-face :foreground field)
      (font-lock-type-face ,@TY)                                  ; Type
      (font-lock-preprocessor-face ,@ANNO)                        ; PreProc
      (font-lock-operator-face :foreground op)                    ; Operator
      (font-lock-negation-char-face :foreground op)
      (font-lock-punctuation-face :foreground punc)               ; Delimiter
      (font-lock-bracket-face :foreground punc)
      (font-lock-delimiter-face :foreground punc)
      (font-lock-misc-punctuation-face :foreground punc)
      (font-lock-warning-face :foreground warn)

      ;;;; tree-sitter captures
      (ts.comment ,@CM)                                           ; links to Comment
      (ts.comment.todo :foreground bg :background anno)
      (ts.comment.error :foreground bg :background error)
      (ts.comment.warning :foreground bg :background warn)
      (ts.comment.note :foreground bg :background info)
      (ts.keyword ,@KW)
      (ts.keyword.function ,@KW)
      (ts.keyword.operator :foreground kw)
      (ts.keyword.return ,@KW)
      (ts.keyword.import ,@ANNO)
      (ts.keyword.directive ,@ANNO)
      (ts.keyword.exception ,@KW)
      (ts.conditional ,@KW)
      (ts.repeat ,@KW)
      (ts.label :foreground kw)
      (ts.function :foreground fn)
      (ts.function.call :foreground fn)
      (ts.function.method :foreground fn)
      (ts.function.method.call :foreground fn)
      (ts.function.builtin :foreground fn :slant 'italic)
      (ts.function.macro ,@ANNO)
      (ts.constructor ,@TY)
      (ts.type ,@TY)
      (ts.type.builtin ,@TY)
      (ts.type.definition ,@TY)
      (ts.type.qualifier ,@KW)
      ;; namespaces, modules and crates read type-like, as in the JetBrains schemes
      (ts.module ,@TY)
      (ts.namespace ,@TY)
      (ts.attribute ,@ANNO)
      (ts.variable :foreground fg)
      (ts.variable.builtin :foreground kw :slant 'italic)
      (ts.variable.parameter :foreground param)
      (ts.variable.member :foreground field)
      (ts.property :foreground field)
      (ts.field :foreground field)
      (ts.parameter :foreground param)
      (ts.constant :foreground const)
      (ts.constant.builtin :foreground const)
      (ts.constant.macro ,@ANNO)
      (ts.boolean :foreground const)
      (ts.number :foreground num)
      (ts.number.float :foreground num)
      (ts.string :foreground str)
      (ts.string.escape :foreground anno)
      (ts.string.special :foreground anno)
      (ts.character :foreground const)
      (ts.operator :foreground op)
      (ts.punctuation.delimiter :foreground punc)
      (ts.punctuation.bracket :foreground punc)
      (ts.punctuation.special :foreground anno)
      (ts.tag :foreground kw)
      (ts.tag.attribute :foreground ty)
      (ts.tag.delimiter :foreground punc)
      (ts.markup.strong :weight 'bold)
      (ts.markup.italic :slant 'italic)
      (ts.markup.strikethrough :strike-through t)
      (ts.markup.heading :foreground ty :weight 'bold)
      (ts.markup.link :foreground glob :underline t)
      (ts.markup.link.url :foreground glob :underline t)
      (ts.markup.raw :foreground str)
      (ts.markup.list :foreground punc)
      (ts.diff.plus :foreground add)
      (ts.diff.minus :foreground delete)
      (ts.diff.delta :foreground change)

      ;;;; LSP semantic tokens: where C++ and Rust globals, statics and constants
      ;;;; get their own colour
      (ts.lsp.type.namespace ,@TY)
      (ts.lsp.type.type ,@TY)
      (ts.lsp.type.class ,@TY)
      (ts.lsp.type.struct ,@TY)
      (ts.lsp.type.enum ,@TY)
      (ts.lsp.type.union ,@TY)
      (ts.lsp.type.interface ,@TY)
      (ts.lsp.type.typeAlias ,@TY)
      (ts.lsp.type.typeParameter ,@TY)
      (ts.lsp.type.builtinType ,@TY)
      (ts.lsp.type.parameter :foreground param)
      (ts.lsp.type.variable :foreground fg)
      (ts.lsp.type.property :foreground field)
      (ts.lsp.type.function :foreground fn)
      (ts.lsp.type.method :foreground fn)
      (ts.lsp.type.macro ,@ANNO)
      (ts.lsp.type.keyword ,@KW)
      (ts.lsp.type.selfKeyword ,@KW)
      (ts.lsp.type.enumMember :foreground const)
      (ts.lsp.type.operator :foreground op)
      (ts.lsp.type.comment ,@CM)
      ;; rust-analyzer's unresolved names; JetBrains marks them with a dotted
      ;; underline in the error tint
      (ts.lsp.type.unresolvedReference :underline (list :style 'dots :color error))
      ;; modifiers: the differentiators
      (ts.lsp.typemod.variable.global ,@GLOB)
      (ts.lsp.typemod.variable.static ,@GLOB)
      (ts.lsp.typemod.variable.readonly :foreground const)
      (ts.lsp.typemod.variable.constant :foreground const)
      (ts.lsp.typemod.variable.defaultLibrary :foreground const)
      (ts.lsp.typemod.function.defaultLibrary :foreground fn)
      (ts.lsp.typemod.function.readonly :foreground fn)
      (ts.lsp.typemod.property.readonly :foreground field)
      (ts.lsp.typemod.parameter.readonly :foreground param)
      ;; lisp/curse.el: its reports' names are Special
      (curse-echo :foreground anno))))

(defmacro guara-define-theme (name variant docstring)
  "Define the Guara theme NAME from the palette VARIANT."
  (let ((palette (alist-get variant guara-palettes)))
    (unless palette (error "No Guara palette named %s" variant))
    `(def-doom-theme ,name ,docstring
       :family 'guara
       :background-mode ',(if (plist-get palette :dark) 'dark 'light)
       ,(guara--defs palette)
       ,(guara--faces palette))))

(provide 'guara-faces)
