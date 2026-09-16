;;; lisp/lsp-semantic.el -*- lexical-binding: t; -*-
;;
;; LSP semantic tokens, layered the way Neovim layers them.
;;
;; Neovim paints a token with @lsp.type.TYPE, then @lsp.mod.MOD for each of
;; its modifiers, then @lsp.typemod.TYPE.MOD, each over the last, and Groselha
;; and Guara rely on all three -- a static variable, a readonly parameter.
;; lsp-mode has faces per type and per modifier, but none for the two together.
;;
;; - Faces are named after the Neovim groups (`ts.lsp.type.variable',
;;   `ts.lsp.mod.static', `ts.lsp.typemod.variable.static') for whatever a
;;   server's legend contains, so no per-client tables are involved.
;; - Token types a parse tree already knows exactly paint nothing, and the
;;   captures from ts-queries.el stand.
;; - A type Neovim has no default link for paints only if the theme sets its
;;   face, as in Neovim, where an undefined group draws nothing. That is decided
;;   when a server starts, so restart the workspace after switching theme.
;; - Once lsp-mode has fontified a region, the TYPE+MOD faces go on top.

(require 'cl-lib)
(require 'seq)
(require 'ts-queries)

(defcustom ts-lsp-ink-declarations nil
  "Paint the declaration of a static or global variable as a plain variable.
Groselha turns this on: the declaration states the type in the accent
already, so the name adds nothing there."
  :type 'boolean
  :group 'ts-queries)

(defconst ts-lsp--deferred-types
  '("keyword" "modifier" "string" "number" "regexp" "operator" "decorator" "macro")
  "Token types left to the tree-sitter queries.
Neovim links these to groups the parse tree already sets exactly; repainting
them would, for one, cover Rust's panic family in the macro colour.")

(defconst ts-lsp--type-links
  '(("class" . "type") ("comment" . "comment") ("enum" . "type")
    ("enumMember" . "constant") ("event" . "type") ("function" . "function")
    ("interface" . "type") ("method" . "function.method") ("namespace" . "module")
    ("parameter" . "variable.parameter") ("property" . "property") ("struct" . "type")
    ("type" . "type") ("typeParameter" . "type.definition") ("variable" . "variable"))
  "Neovim's default links from @lsp.type.TYPE to a tree-sitter capture.")

(defun ts-lsp--declare (face &optional parent)
  "Declare FACE, inheriting PARENT if given; return FACE."
  (unless (get face 'face-defface-spec)
    (custom-declare-face
     face (if parent `((t :inherit ,parent)) '((t)))
     (format "Neovim's semantic token group @%s." (string-remove-prefix "ts." (symbol-name face)))
     :group 'ts-queries))
  face)

(defun ts-lsp--type-face (type)
  "Face for token TYPE, or nil to leave the tree-sitter colour alone."
  (unless (member type ts-lsp--deferred-types)
    (let ((face (intern (concat "ts.lsp.type." type)))
          (link (cdr (assoc type ts-lsp--type-links))))
      (when (or link (get face 'theme-face))
        (ts-lsp--declare face (and link (ts-queries--face link)))))))

(defun ts-lsp--build-face-map-a (_fn identifiers _faces category &rest _)
  "Map a server's semantic token legend onto the Neovim-named faces."
  (apply #'vector
         (mapcar (lambda (id)
                   (if (string-suffix-p "modifier" category)
                       (ts-lsp--declare (intern (concat "ts.lsp.mod." id)))
                     (ts-lsp--type-face id)))
                 identifiers)))

(advice-add 'lsp--semantic-tokens-build-face-map :around #'ts-lsp--build-face-map-a)

(defun ts-lsp--suffixes (faces prefix)
  "What follows PREFIX in the names of FACES that start with it."
  (let (names)
    (dolist (face faces (nreverse names))
      (when (and (symbolp face) (string-prefix-p prefix (symbol-name face)))
        (push (substring (symbol-name face) (length prefix)) names)))))

(defun ts-lsp--ink-p (type mods)
  "Non-nil for the declaration of a static or global that is not constant."
  (and (or (equal type "static")
           (and (equal type "variable")
                (seq-intersection mods '("static" "global" "fileScope" "globalScope"))))
       (seq-intersection mods '("declaration" "definition"))
       (not (seq-intersection mods '("constant" "readonly")))))

(defun ts-lsp--fontify (limit)
  "Put the @lsp.typemod faces over tokens lsp-mode fontified before LIMIT."
  (let ((pos (point)))
    (while (< pos limit)
      (let ((next (next-single-property-change pos 'face nil limit))
            (faces (get-text-property pos 'face)))
        (when (and (consp faces) (not (eq faces (get-text-property pos 'ts-lsp-faces))))
          (let ((type (car (ts-lsp--suffixes faces "ts.lsp.type.")))
                (mods (ts-lsp--suffixes faces "ts.lsp.mod.")))
            (when (and type mods)
              (let ((extra (seq-keep (lambda (mod)
                                       (let ((face (intern (format "ts.lsp.typemod.%s.%s" type mod))))
                                         (and (get face 'theme-face) (ts-lsp--declare face))))
                                     mods)))
                (when (and ts-lsp-ink-declarations (ts-lsp--ink-p type mods))
                  (push 'ts.variable extra))
                (when extra
                  (let ((new (append extra faces)))
                    (with-silent-modifications
                      (put-text-property pos next 'face new)
                      (put-text-property pos next 'ts-lsp-faces new))))))))
        (setq pos next))))
  nil)

(defun ts-lsp-h ()
  "Layer the TYPE+MOD faces in buffers showing semantic tokens."
  (if (bound-and-true-p lsp-semantic-tokens-mode)
      (font-lock-add-keywords nil '((ts-lsp--fontify)) 'append)
    (font-lock-remove-keywords nil '((ts-lsp--fontify)))))

(add-hook 'lsp-semantic-tokens-mode-hook #'ts-lsp-h)

(provide 'lsp-semantic)
