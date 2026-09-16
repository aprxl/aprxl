;;; lisp/ts-queries.el -*- lexical-binding: t; -*-
;;
;; Neovim's tree-sitter highlighting for C, C++ and Rust, run by Emacs.
;;
;; The Neovim config colours those languages with nvim-treesitter's queries
;; plus its own after/queries corrections, and Groselha and Guara are written
;; against the captures those queries produce (@keyword.type, @function.macro,
;; ...). Emacs's built-in c-ts-mode and rust-ts-mode queries classify code
;; differently, so the themes would not look like themselves on top of them.
;;
;; This file runs the same queries instead, from the snapshots in ../queries,
;; combined the way Neovim combines them: languages named by `; inherits:'
;; first, then LANG/highlights.scm, then after/LANG/highlights.scm.
;;
;; - A capture @x.y paints the face `ts.x.y.LANG', which inherits `ts.x.y',
;;   then `ts.x' -- the fallback Neovim walks when a theme leaves a capture
;;   undefined. Top-level faces fall back on the nearest font-lock face.
;; - Captures are painted in Neovim's order. Neovim sorts them by priority,
;;   then by where the node starts, then by pattern, and the last one wins.
;;   Emacs paints match by match instead, which lets an early pattern such as
;;   (identifier) @variable cover later, more specific ones -- the
;;   after/queries corrections among them. So captures are recorded while a
;;   region is fontified and painted afterwards, sorted.
;; - Neovim-only predicates are rewritten as #match?, #eq? or #pred?.
;; - A pattern the installed grammar or Emacs cannot run is dropped and listed
;;   by `ts-queries-report', so an update costs one pattern, not the file.
;;
;; Snapshots: nvim-treesitter d4d59cb, and the Neovim config's after/queries.
;; To refresh, copy newer files over and run `ts-queries-reload'.

(require 'treesit)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)

(defgroup ts-queries nil
  "Neovim's tree-sitter queries and captures, in Emacs."
  :group 'faces)

(defvar ts-queries-directory
  (expand-file-name "../queries/" (file-name-directory (or load-file-name buffer-file-name)))
  "Root of the query snapshots, laid out like a Neovim runtime directory.")

(defconst ts-queries--modes
  '((c-ts-mode . c) (c++-ts-mode . cpp) (rust-ts-mode . rust))
  "Major modes that run Neovim's queries, and the language each one parses.")

(defconst ts-queries--ignored-captures '("spell" "nospell" "conceal" "none")
  "Captures that carry no colour.")

(defconst ts-queries--fallback-faces
  '(("attribute"   . font-lock-preprocessor-face)
    ("boolean"     . font-lock-constant-face)
    ("character"   . font-lock-constant-face)
    ("comment"     . font-lock-comment-face)
    ("constant"    . font-lock-constant-face)
    ("constructor" . font-lock-type-face)
    ("function"    . font-lock-function-name-face)
    ("keyword"     . font-lock-keyword-face)
    ("label"       . font-lock-constant-face)
    ("module"      . font-lock-constant-face)
    ("number"      . font-lock-number-face)
    ("operator"    . font-lock-operator-face)
    ("property"    . font-lock-property-use-face)
    ("punctuation" . font-lock-punctuation-face)
    ("string"      . font-lock-string-face)
    ("type"        . font-lock-type-face)
    ("variable"    . font-lock-variable-use-face))
  "Emacs faces that top-level captures fall back on when no theme sets them.")

(defconst ts-queries--lua-classes
  '((?a . "A-Za-z") (?d . "0-9") (?l . "a-z") (?u . "A-Z") (?w . "A-Za-z0-9") (?x . "0-9A-Fa-f"))
  "Lua pattern classes, as the inside of an Emacs bracket expression.")

(defvar ts-queries-dropped nil
  "Patterns left out, as (LANG FILE PATTERN REASON).")

(defvar ts-queries--cache (make-hash-table :test #'eq)
  "Compiled font-lock settings per language.")

(defvar ts-queries--predicates (make-hash-table :test #'equal)
  "Generated predicate functions, keyed by what they test.")

(defvar ts-queries--pending nil
  "While a region is fontified, a cell holding the captures recorded so far.")

(defvar-local ts-queries--active nil
  "Non-nil in buffers highlighted by these queries.")

(define-error 'ts-queries-unsupported "Query construct Emacs cannot run")

;;; Reading

(defun ts-queries--read (file)
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (buffer-string))))

(defun ts-queries--inherits (text)
  "Languages TEXT names in its `; inherits:' modeline."
  (when (string-match "^;+ *inherits *: *\\(.*\\)$" text)
    (mapcar (lambda (lang) (intern (string-trim lang "[ (]+" "[ )]+")))
            (split-string (match-string 1 text) "," t))))

(defun ts-queries--file-texts (lang)
  "Query texts Neovim combines for LANG, in order, as (FILE . TEXT)."
  (let* ((base (expand-file-name (format "%s/highlights.scm" lang) ts-queries-directory))
         (after (expand-file-name (format "after/%s/highlights.scm" lang) ts-queries-directory))
         (base-text (ts-queries--read base))
         (after-text (ts-queries--read after)))
    (append (apply #'append (mapcar #'ts-queries--file-texts
                                    (and base-text (ts-queries--inherits base-text))))
            (and base-text (list (cons base base-text)))
            (and after-text (list (cons after after-text))))))

(defun ts-queries--tokenize (text)
  "Tokens of query TEXT as strings, comments left out."
  (let ((tokens '()) (i 0) (n (length text)))
    (while (< i n)
      (let ((c (aref text i)))
        (cond
         ((memq c '(?\s ?\t ?\n ?\r ?\f)) (setq i (1+ i)))
         ((eq c ?\;) (setq i (or (string-search "\n" text i) n)))
         ((eq c ?\")
          (let ((j (1+ i)))
            (while (and (< j n) (not (eq (aref text j) ?\")))
              (setq j (+ j (if (eq (aref text j) ?\\) 2 1))))
            (push (substring text i (min n (1+ j))) tokens)
            (setq i (1+ j))))
         ((memq c '(?\( ?\) ?\[ ?\]))
          (push (string c) tokens)
          (setq i (1+ i)))
         (t
          (let ((j i))
            (while (and (< j n)
                        (not (memq (aref text j) '(?\s ?\t ?\n ?\r ?\f ?\( ?\) ?\[ ?\] ?\" ?\;))))
              (setq j (1+ j)))
            (push (substring text i j) tokens)
            (setq i j))))))
    (nreverse tokens)))

(defun ts-queries--parse (tokens)
  "Nest TOKENS: a () or [] group becomes (:group OPEN CHILDREN)."
  (let ((stack (list (list :root))))
    (dolist (token tokens)
      (pcase token
        ((or "(" "[") (push (list token) stack))
        ((or ")" "]")
         (let ((frame (pop stack)))
           (unless stack (error "Unbalanced %s" token))
           (push (list :group (car frame) (nreverse (cdr frame))) (cdr (car stack)))))
        (_ (push token (cdr (car stack))))))
    (when (cdr stack) (error "Unclosed %s" (car (car stack))))
    (nreverse (cdr (car stack)))))

(defun ts-queries--split (items)
  "Group top-level ITEMS into patterns: an expression plus the captures and
quantifiers that follow it."
  (let (patterns)
    (dolist (item items)
      (if (and patterns (stringp item)
               (or (string-prefix-p "@" item) (member item '("?" "*" "+"))))
          (push item (car patterns))
        (push (list item) patterns)))
    (nreverse (mapcar #'reverse patterns))))

(defun ts-queries--serialize (items)
  (let ((out ""))
    (dolist (item items out)
      (let ((text (if (stringp item)
                      item
                    (concat (nth 1 item)
                            (ts-queries--serialize (nth 2 item))
                            (if (equal (nth 1 item) "(") ")" "]")))))
        (setq out (cond ((string-empty-p out) text)
                        ((member text '("?" "*" "+")) (concat out text))
                        (t (concat out " " text))))))))

;;; Translating

(defun ts-queries--face (name)
  "Declare the face `ts.NAME' and every face it inherits from; return it."
  (let ((parts (split-string name "\\." t))
        (parent nil))
    (dotimes (k (length parts) parent)
      (let ((face (intern (concat "ts." (string-join (seq-take parts (1+ k)) ".")))))
        (unless (get face 'face-defface-spec)
          (custom-declare-face
           face
           `((t :inherit ,(or parent (alist-get (car parts) ts-queries--fallback-faces
                                                'default nil #'equal))))
           (format "Neovim's tree-sitter capture @%s."
                   (string-remove-prefix "ts." (symbol-name face)))
           :group 'ts-queries))
        (setq parent face)))))

(defun ts-queries--capture (capture lang ctx)
  "CAPTURE (\"@x.y\") rewritten for LANG's pattern CTX, or nil to drop it.
A colour capture becomes a function that records its node for
`ts-queries--fontify-a' to paint; private @_ captures stay as they are."
  (let ((name (substring capture 1)))
    (cond
     ((string-prefix-p "_" name) capture)
     ((member name ts-queries--ignored-captures) nil)
     (t
      (concat
       "@"
       (symbol-name
        (with-memoization (gethash name (plist-get ctx :captures))
          (let ((face (ts-queries--face (format "%s.%s" name lang)))
                (priority (plist-get ctx :priority))
                (index (plist-get ctx :index))
                (fn (intern (format "ts-queries--%s-%d-%s" lang (plist-get ctx :index) name))))
            (defalias fn
              (lambda (node &rest _)
                (when ts-queries--pending
                  (push (vector (car priority) (treesit-node-start node) index
                                (treesit-node-end node) face)
                        (car ts-queries--pending)))))
            fn))))))))

(defun ts-queries--lua-to-regexp (pattern)
  "Emacs regexp matching a whole node's text the way Lua PATTERN does, or nil."
  (catch 'unsupported
    (when (string-suffix-p ".*$" pattern)   ; `X.*$' matches whatever `X' matches
      (setq pattern (substring pattern 0 -3)))
    (let ((n (length pattern)) (i 0) (parts '()))
      (while (< i n)
        (let ((c (aref pattern i)))
          (push
           (cond
            ((and (eq c ?^) (= i 0)) "\\`")
            ((and (eq c ?$) (= i (1- n))) "\\'")
            ((eq c ?.) "\\(?:.\\|\n\\)")
            ((eq c ?%)
             (setq i (1+ i))
             (let* ((k (and (< i n) (aref pattern i)))
                    (class (and k (alist-get k ts-queries--lua-classes))))
               (cond (class (concat "[" class "]"))
                     ((and k (string-match-p "[[:punct:]]" (string k))) (regexp-quote (string k)))
                     (t (throw 'unsupported nil)))))
            ((eq c ?\[)
             (let ((j (1+ i)) (set "["))
               (when (and (< j n) (eq (aref pattern j) ?^))
                 (setq set "[^" j (1+ j)))
               (while (and (< j n) (not (eq (aref pattern j) ?\])))
                 (if (eq (aref pattern j) ?%)
                     (let ((class (and (< (1+ j) n)
                                       (alist-get (aref pattern (1+ j)) ts-queries--lua-classes))))
                       (unless class (throw 'unsupported nil))
                       (setq set (concat set class) j (+ j 2)))
                   (setq set (concat set (string (aref pattern j))) j (1+ j))))
               (when (>= j n) (throw 'unsupported nil))
               (setq i j)
               (concat set "]")))
            ((eq c ?-) "*?")
            ((memq c '(?* ?+ ??)) (string c))
            (t (regexp-quote (string c))))
           parts))
        (setq i (1+ i)))
      (apply #'concat (nreverse parts)))))

(defun ts-queries--query-regexp (regexp)
  "REGEXP as a #match? predicate can take it, or nil if it has to run in Lisp.
Backslashes do not survive the trip through a query string, so only the
anchors can be kept, as ^ and $."
  (let ((r regexp))
    (when (string-prefix-p "\\`" r) (setq r (concat "^" (substring r 2))))
    (when (string-suffix-p "\\'" r) (setq r (concat (substring r 0 -2) "$")))
    (unless (string-match-p "[\\\"]" r) r)))

(defun ts-queries--node-text (node)
  (treesit-node-text node t))

(defun ts-queries--pred (key make)
  "Symbol of the predicate function for KEY, defined by calling MAKE once."
  (with-memoization (gethash key ts-queries--predicates)
    (let ((symbol (intern (format "ts-queries--p%d" (hash-table-count ts-queries--predicates)))))
      (defalias symbol (funcall make))
      symbol)))

(defun ts-queries--convert-predicate (items ctx)
  "Query items standing in for the Neovim predicate ITEMS (name first)."
  (let* ((name (car items))
         (args (cdr items))
         (negated (string-prefix-p "#not-" name))
         (kind (replace-regexp-in-string "\\`#\\(?:not-\\)?\\|[?!]\\'" "" name))
         (capture (seq-find (lambda (arg) (string-prefix-p "@" arg)) args))
         (strings (mapcar #'read (seq-filter (lambda (arg) (string-prefix-p "\"" arg)) args)))
         (symbols (seq-remove (lambda (arg) (string-match-p "\\`[@\"]" arg)) args)))
    (cl-flet ((lisp (test)
                (let ((fn (ts-queries--pred
                           (list kind negated strings symbols)
                           (lambda () (if negated (lambda (node) (not (funcall test node))) test)))))
                  (list (list :group "(" (list "#pred?" (symbol-name fn) capture))))))
      (pcase kind
        ("set"
         (when (equal (car symbols) "priority")
           (setcar (plist-get ctx :priority) (string-to-number (cadr symbols))))
         nil)
        ((or "offset" "gsub" "trim") nil)
        ("eq"
         (if negated
             (lisp (lambda (node) (equal (ts-queries--node-text node) (car strings))))
           (list (list :group "(" (cons "#eq?" args)))))
        ("any-of"
         (lisp (lambda (node) (member (ts-queries--node-text node) strings))))
        ("contains"
         (lisp (lambda (node)
                 (let ((text (ts-queries--node-text node)))
                   (seq-some (lambda (s) (string-search s text)) strings)))))
        ("lua-match"
         (let* ((regexp (or (ts-queries--lua-to-regexp (car strings))
                            (signal 'ts-queries-unsupported
                                    (list (format "Lua pattern %S" (car strings))))))
                (plain (and (not negated) (ts-queries--query-regexp regexp))))
           (if plain
               (list (list :group "(" (list "#match?" capture (prin1-to-string plain))))
             (lisp (lambda (node)
                     (let ((case-fold-search nil))
                       (string-match-p regexp (ts-queries--node-text node))))))))
        ("has-parent"
         (lisp (lambda (node)
                 (member (treesit-node-type (treesit-node-parent node)) symbols))))
        ("has-ancestor"
         (lisp (lambda (node)
                 (treesit-parent-until
                  node (lambda (parent) (member (treesit-node-type parent) symbols))))))
        (_ (signal 'ts-queries-unsupported (list (format "predicate %s" name))))))))

(defun ts-queries--convert-items (items lang ctx)
  (let (out)
    (dolist (item items (nreverse out))
      (cond
       ((not (stringp item))
        (let ((children (nth 2 item)))
          (if (and (stringp (car children)) (string-prefix-p "#" (car children)))
              (dolist (new (ts-queries--convert-predicate
                            (mapcar (lambda (arg)
                                      (if (string-prefix-p "@" arg)
                                          (or (ts-queries--capture arg lang ctx) arg)
                                        arg))
                                    children)
                            ctx))
                (push new out))
            (push (list :group (nth 1 item) (ts-queries--convert-items children lang ctx))
                  out))))
       ((string-prefix-p "@" item)
        (when-let* ((renamed (ts-queries--capture item lang ctx)))
          (push renamed out)))
       (t (push item out))))))

(defun ts-queries--convert (pattern lang index)
  "PATTERN, the INDEXth for LANG, as a query string, or (nil . REASON)."
  (let ((ctx (list :index index
                   :priority (list 100)
                   :captures (make-hash-table :test #'equal))))
    (condition-case err
        (ts-queries--serialize (ts-queries--convert-items pattern lang ctx))
      (ts-queries-unsupported (cons nil (cadr err))))))

;;; Building and painting

(defun ts-queries--query (lang candidates)
  "CANDIDATES, a list of (FILE . QUERY), compiled together as one query for LANG.
All of C++'s patterns compile together in a tenth of a second but take a
second one at a time, so they are only tried one at a time when the whole
fails, to find and drop the patterns that broke it. Nil when none are left."
  (condition-case nil
      (treesit-query-compile lang (mapconcat #'cdr candidates "\n") t)
    (error
     (when-let* ((valid (seq-filter
                         (pcase-lambda (`(,file . ,query))
                           (condition-case err
                               (treesit-query-compile lang query t)
                             (error
                              (push (list lang file query (error-message-string err))
                                    ts-queries-dropped)
                              nil)))
                         candidates)))
       (treesit-query-compile lang (mapconcat #'cdr valid "\n"))))))

(defun ts-queries--build (lang)
  "Font-lock settings for LANG, compiled from the query snapshots."
  (setq ts-queries-dropped (seq-remove (lambda (d) (eq (car d) lang)) ts-queries-dropped))
  (let ((index 0) candidates)
    (pcase-dolist (`(,file . ,text) (ts-queries--file-texts lang))
      (dolist (pattern (condition-case err
                           (ts-queries--split (ts-queries--parse (ts-queries--tokenize text)))
                         (error
                          (push (list lang file "" (error-message-string err)) ts-queries-dropped)
                          nil)))
        (let ((query (ts-queries--convert pattern lang (cl-incf index))))
          (if (consp query)
              (push (list lang file (ts-queries--serialize pattern) (cdr query)) ts-queries-dropped)
            (push (cons file query) candidates)))))
    (when-let* ((query (and candidates (ts-queries--query lang (nreverse candidates)))))
      (treesit-font-lock-rules :language lang :feature 'ts-queries :override t query))))

(defun ts-queries--settings (lang)
  (with-memoization (gethash lang ts-queries--cache)
    (and (treesit-language-available-p lang)
         (ts-queries--build lang))))

(defun ts-queries--capture< (a b)
  "Neovim's painting order: priority, then node start, then pattern."
  (or (< (aref a 0) (aref b 0))
      (and (= (aref a 0) (aref b 0))
           (or (< (aref a 1) (aref b 1))
               (and (= (aref a 1) (aref b 1))
                    (< (aref a 2) (aref b 2)))))))

(defun ts-queries--fontify-a (fn start end &rest args)
  "Fontify START..END with FN, then paint the recorded captures in order."
  (if (not ts-queries--active)
      (apply fn start end args)
    (let ((ts-queries--pending (list nil)))
      (prog1 (apply fn start end args)
        (with-silent-modifications
          (dolist (capture (sort (car ts-queries--pending) #'ts-queries--capture<))
            (let ((beg (max start (aref capture 1)))
                  (fin (min end (aref capture 3))))
              (when (< beg fin)
                (put-text-property beg fin 'face (aref capture 4))))))))))

(advice-add 'treesit-font-lock-fontify-region :around #'ts-queries--fontify-a)

(defun ts-queries-h ()
  "Highlight this C, C++ or Rust tree-sitter buffer with Neovim's queries."
  (when-let* ((lang (cdr (seq-find (lambda (entry) (derived-mode-p (car entry)))
                                   ts-queries--modes)))
              (settings (ts-queries--settings lang)))
    (setq-local treesit-font-lock-settings settings
                treesit-font-lock-feature-list '((ts-queries))
                ts-queries--active t)
    (treesit-font-lock-recompute-features)))

(dolist (entry ts-queries--modes)
  (add-hook (intern (format "%s-hook" (car entry))) #'ts-queries-h))

(defun ts-queries-reload ()
  "Re-read the query snapshots and re-highlight the buffers using them."
  (interactive)
  (clrhash ts-queries--cache)
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when ts-queries--active
        (ts-queries-h)
        (font-lock-flush)))))

(defun ts-queries-report ()
  "List the query patterns that were left out, and why."
  (interactive)
  (with-current-buffer (get-buffer-create "*ts-queries*")
    (let ((inhibit-read-only t))
      (erase-buffer)
      (if (null ts-queries-dropped)
          (insert "Every pattern loaded.\n")
        (pcase-dolist (`(,lang ,file ,pattern ,reason) (reverse ts-queries-dropped))
          (insert (format "%s  %s\n  %s\n  %s\n\n"
                          lang (file-relative-name file ts-queries-directory) reason pattern)))))
    (special-mode)
    (display-buffer (current-buffer))))

(provide 'ts-queries)
