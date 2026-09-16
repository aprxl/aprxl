;;; lisp/curse.el -*- lexical-binding: t; -*-
;;
;; Curse, from ~/Develop/Curse: mouse gestures for Normal state.
;;
;; Nothing here changes what the keyboard does. Every gesture is a question you
;; would otherwise stop and type, bound to the hand already on the mouse:
;;
;;   click a symbol       peek: diagnostics under the pointer, then hover, in one float
;;   click it again       put the float away
;;   drag a selection     on release it is on the clipboard, no y
;;   double click a name  every occurrence in the buffer lights up, with a count
;;   Ctrl click           go to definition
;;   Shift click          find references
;;   Ctrl right click     jump back
;;   thumb buttons        the jump list, as browser history: back and forward
;;   right click          the context menu, with Curse's items on top
;;
;; Every gesture says what it did on one line in the echo area, never in
;; *Messages*:   curse  <the thing acted on>  <what happened>  <an aside>
;; A click on whitespace or punctuation says nothing and stays a plain click.
;;
;; Where this differs from the Neovim plugin:
;; - The :Curse actions are commands: `curse-peek', `curse-occurrences',
;;   `curse-clear', `curse-definition', `curse-references', `curse-rename',
;;   `curse-code-action', `curse-copy-location' and `curse-status'.
;;   `curse-mode' is enable, disable and toggle.
;; - The trail, off by default in Neovim, is not ported.
;; - Emacs delivers the first click of a double click as a click of its own,
;;   so a double click opens a peek that the second click puts away again.
;; - Diagnostics come from Flycheck; hover, highlights and locations from
;;   lsp-mode. Buffers without a server fall back the way Neovim's do.

(require 'cl-lib)
(require 'subr-x)
(require 'evil)
(require 'xref)

(declare-function posframe-show "posframe")
(declare-function posframe-hide "posframe")
(declare-function posframe-workable-p "posframe")
(declare-function posframe-poshandler-point-bottom-left-corner "posframe")
(declare-function flycheck-overlay-errors-at "flycheck")
(declare-function flycheck-overlay-errors-in "flycheck")
(declare-function flycheck-error-level "flycheck")
(declare-function flycheck-error-level-severity "flycheck")
(declare-function flycheck-error-message "flycheck")
(declare-function flycheck-error-group "flycheck")
(declare-function lsp-feature? "lsp-mode")
(declare-function lsp-request-async "lsp-mode")
(declare-function lsp--text-document-position-params "lsp-mode")
(declare-function lsp--render-on-hover-content "lsp-mode")
(declare-function lsp--range-to-region "lsp-mode")
(declare-function lsp--locations-to-xref-items "lsp-mode")
(declare-function lsp-show-xrefs "lsp-mode")
(declare-function lsp-rename "lsp-mode")
(declare-function lsp-execute-code-action "lsp-mode")
(declare-function lsp:hover-contents "lsp-protocol")
(declare-function lsp:document-highlight-range "lsp-protocol")
(declare-function lsp:document-highlight-kind? "lsp-protocol")
(declare-function doom-project-root "doom-lib")

;;; Options and faces

(defgroup curse nil
  "Mouse gestures for Evil's Normal state."
  :group 'mouse
  :prefix "curse-")

(defcustom curse-echo t
  "Whether gestures report what they did in the echo area."
  :type 'boolean)

(defcustom curse-peek-max-width 84
  "Widest the peek float grows, in columns."
  :type 'integer)

(defcustom curse-peek-max-height 20
  "Tallest the peek float grows, in lines."
  :type 'integer)

(defcustom curse-yank-register ?+
  "Register a mouse selection goes to; the system clipboard by default."
  :type 'character)

(defcustom curse-yank-flash-duration 0.15
  "Seconds the flash on a captured selection lasts."
  :type 'number)

(defcustom curse-jump-to-single t
  "Go straight to a lone definition or reference instead of listing it.
A list with one entry in it is a worse answer than the answer itself."
  :type 'boolean)

(defcustom curse-ignored-modes
  '(special-mode ghostel-mode +doom-dashboard-mode dired-mode minibuffer-mode)
  "Modes where a click means something other than \"read this code\"."
  :type '(repeat symbol))

(defface curse-yank '((t :inherit isearch))
  "The flash on a captured selection; Neovim's CurseYank.")

(defface curse-occurrence '((t :inherit lazy-highlight))
  "Occurrences of a double-clicked name; Neovim's CurseOccurrence.")

(defface curse-occurrence-write '((t :inherit isearch))
  "Occurrences that assign to the name; Neovim's CurseOccurrenceWrite.")

(defface curse-echo '((t :inherit font-lock-constant-face))
  "The names in Curse's reports; Neovim's CurseEcho, which links to Special.")

;;; Small things every gesture wants

(defun curse--report (&rest chunks)
  "Say CHUNKS, each (TEXT . FACE), after \"curse  \" in the echo area.
Deliberately not in *Messages*: these are commentary on a gesture."
  (when curse-echo
    (let ((message-log-max nil))
      (message "%s"
               (apply #'concat
                      (propertize "curse  " 'face 'curse-echo)
                      (mapcar (lambda (chunk)
                                (if (cdr chunk)
                                    (propertize (car chunk) 'face (cdr chunk))
                                  (car chunk)))
                              chunks))))))

(defun curse--plural (count singular)
  (format "%d %s%s" count singular (if (= count 1) "" "s")))

(defun curse--here ()
  "The current file and line, relative to the project, with forward slashes."
  (let* ((file buffer-file-name)
         (root (and file (fboundp 'doom-project-root) (doom-project-root))))
    (format "%s:%d"
            (cond ((null file) "[No Name]")
                  ((and root (file-in-directory-p file root)) (file-relative-name file root))
                  (t (abbreviate-file-name file)))
            (line-number-at-pos))))

(defun curse--ignored-p (&optional buffer)
  "Non-nil when BUFFER is a surface that is not code to read."
  (with-current-buffer (or buffer (current-buffer))
    (or (minibufferp) (derived-mode-p curse-ignored-modes))))

(defun curse--lsp-p (method)
  "Non-nil when a language server here answers METHOD."
  (and (bound-and-true-p lsp-mode) (lsp-feature? method)))

(defun curse--symbol-at (pos)
  "The symbol whose characters include POS, as (NAME . START), or nil."
  (save-excursion
    (goto-char pos)
    (when (and (not (eobp)) (memq (char-syntax (char-after)) '(?w ?_)))
      (when-let* ((bounds (bounds-of-thing-at-point 'symbol)))
        (cons (buffer-substring-no-properties (car bounds) (cdr bounds))
              (car bounds))))))

(defun curse--target (event)
  "Where mouse EVENT points, as a plist, or nil when it is not over code.
:window, :buffer and :pos; :on-text is nil past the end of a line or over
the line numbers; :word and :start name the symbol under the pointer."
  (let* ((posn (event-end event))
         (window (posn-window posn))
         (pos (posn-point posn)))
    (when (and (windowp window) (window-live-p window) (integerp pos)
               (null (posn-area posn)))
      (with-current-buffer (window-buffer window)
        (unless (curse--ignored-p)
          (let* ((x (car (posn-x-y posn)))
                 (on-text (and (< pos (point-max))
                               (not (eq (char-after pos) ?\n))
                               (not (and display-line-numbers
                                         (< x (line-number-display-width t))))))
                 (symbol (and on-text (curse--symbol-at pos))))
            (list :window window :buffer (current-buffer) :pos pos :on-text on-text
                  :word (car symbol) :start (cdr symbol))))))))

(defun curse--fall-through (event)
  "Run what EVENT would have run with Curse off."
  (let* ((curse-mode nil)
         (command (key-binding (vector (car event)))))
    (when (commandp command)
      (call-interactively command nil (vector event)))))

;;; Peek

(defconst curse--peek-buffer " *curse-peek*")

(defvar curse--peek nil
  "The open peek float: (:key :word :window :buffer :point :start).")

(defvar curse--peek-token 0
  "Bumped on every peek; an answer carrying a stale token is dropped.")

(defun curse-peek-close ()
  "Put the peek float away."
  (interactive)
  (remove-hook 'post-command-hook #'curse--peek-watch)
  (when curse--peek
    (setq curse--peek nil)
    (when (fboundp 'posframe-hide)
      (posframe-hide curse--peek-buffer))))

(defun curse--peek-watch ()
  "Close the float once the cursor, the buffer or the view moves."
  (when-let* ((state curse--peek))
    (unless (and (eq (selected-window) (plist-get state :window))
                 (eq (current-buffer) (plist-get state :buffer))
                 (= (point) (plist-get state :point))
                 (= (window-start) (plist-get state :start))
                 (not (evil-insert-state-p)))
      (curse-peek-close))))

(defun curse--diagnostics-at (pos)
  "Flycheck errors covering POS, else every error on its line; worst first.
The narrow answer wins when there is one: clicking one underlined argument
should not recite every warning on the row."
  (when (bound-and-true-p flycheck-mode)
    (let ((errors (or (flycheck-overlay-errors-at pos)
                      (save-excursion
                        (goto-char pos)
                        (flycheck-overlay-errors-in
                         (line-beginning-position)
                         (min (point-max) (1+ (line-end-position))))))))
      (sort (delete-dups (copy-sequence errors))
            (lambda (a b)
              (> (flycheck-error-level-severity (flycheck-error-level a))
                 (flycheck-error-level-severity (flycheck-error-level b))))))))

(defun curse--diagnostic-line (err)
  (let* ((level (flycheck-error-level err))
         (source (flycheck-error-group err))
         (message (replace-regexp-in-string
                   "[ \t]*[\r\n]+[ \t]*" " " (or (flycheck-error-message err) ""))))
    (concat (propertize (format "%s:" level)
                        'face (pcase level
                                ('error 'flycheck-error-list-error)
                                ('warning 'flycheck-error-list-warning)
                                (_ 'flycheck-error-list-info)))
            " " message
            (and source (format "  (%s)" source)))))

(defun curse--hover-text (hover)
  (when-let* ((contents (and hover (lsp:hover-contents hover))))
    (let ((text (string-trim (lsp--render-on-hover-content contents t))))
      (unless (string-empty-p text) text))))

(defun curse--peek-open (window pos key word text)
  (require 'posframe)
  (curse-peek-close)
  (when (posframe-workable-p)
    (with-selected-window window
      (posframe-show curse--peek-buffer
                     :string text
                     :position pos
                     :poshandler #'posframe-poshandler-point-bottom-left-corner
                     :max-width curse-peek-max-width
                     :max-height curse-peek-max-height
                     :border-width 1
                     :border-color (face-attribute 'vertical-border :foreground nil t)
                     :background-color (face-attribute 'default :background nil t)
                     :foreground-color (face-attribute 'default :foreground nil t))
      (setq curse--peek (list :key key :word word :window window
                              :buffer (window-buffer window)
                              :point (point) :start (window-start))))
    (add-hook 'post-command-hook #'curse--peek-watch)))

(defun curse--peek-show (window pos key word)
  "Peek at POS in WINDOW: the diagnostics there, then hover.
KEY names the symbol, so the same one asked twice puts the float away."
  (if (and curse--peek (equal (plist-get curse--peek :key) key))
      (let ((dismissed (plist-get curse--peek :word)))
        (curse-peek-close)
        (curse--report (cons dismissed 'curse-echo)
                       '("  peek closed" . font-lock-comment-face)))
    (let* ((token (cl-incf curse--peek-token))
           (buffer (window-buffer window))
           (errors (with-current-buffer buffer (curse--diagnostics-at pos)))
           (finish
            (lambda (hover)
              (when (and (= token curse--peek-token)
                         (window-live-p window)
                         (eq (window-buffer window) buffer))
                (let ((parts (delq nil (list (and errors (mapconcat #'curse--diagnostic-line
                                                                    errors "\n"))
                                             hover))))
                  (if parts
                      (curse--peek-open
                       window pos key word
                       (string-join parts (concat "\n" (propertize "───" 'face 'font-lock-comment-face)
                                                  "\n")))
                    (curse-peek-close))
                  (curse--report
                   (cons word 'curse-echo)
                   (if parts
                       (cons (concat "  " (string-join
                                           (delq nil (list (and errors (curse--plural (length errors)
                                                                                      "diagnostic"))
                                                           (and hover "hover")))
                                           " and "))
                             nil)
                     '("  nothing to report" . font-lock-comment-face))))))))
      (with-current-buffer buffer
        (if (curse--lsp-p "textDocument/hover")
            (save-excursion
              (goto-char pos)
              (lsp-request-async "textDocument/hover"
                                 (lsp--text-document-position-params)
                                 (lambda (hover) (funcall finish (curse--hover-text hover)))
                                 :error-handler (lambda (_) (funcall finish nil))
                                 :mode 'detached))
          (funcall finish nil))))))

(defun curse-peek ()
  "Peek at the symbol at point: diagnostics, then hover, in one float."
  (interactive)
  (let ((symbol (curse--symbol-at (point))))
    (curse--peek-show (selected-window) (point)
                      (format "%s:%s:%s" (buffer-name) (cdr symbol) (car symbol))
                      (or (car symbol) "this line"))))

(defun curse-click (event)
  "Left click: move point, then peek if the pointer is on a symbol."
  (interactive "e")
  (let ((target (curse--target event)))
    (if (not (plist-get target :word))
        (curse--fall-through event)
      (mouse-set-point event)
      (curse--peek-show (plist-get target :window)
                        (plist-get target :pos)
                        (format "%s:%s:%s" (buffer-name (plist-get target :buffer))
                                (plist-get target :start) (plist-get target :word))
                        (plist-get target :word)))))

;;; Yank on release

(defun curse--describe (text type)
  "TEXT counted in whichever unit reads better."
  (let ((newlines (cl-count ?\n text)))
    (if (or (eq type 'line) (> newlines 1))
        (curse--plural (+ newlines (if (string-suffix-p "\n" text) 0 1)) "line")
      (curse--plural (length text) "character"))))

(defun curse--flash (beg end)
  (let ((overlay (make-overlay beg end)))
    (overlay-put overlay 'face 'curse-yank)
    (overlay-put overlay 'priority 250)
    (run-at-time curse-yank-flash-duration nil #'delete-overlay overlay)))

(defun curse-yank ()
  "Put the Visual selection on the clipboard and leave Visual state."
  (interactive)
  (when (and (evil-visual-state-p) (not (curse--ignored-p)))
    (let* ((range (evil-visual-range))
           (beg (evil-range-beginning range))
           (end (evil-range-end range))
           (type (evil-visual-type))
           ;; Counted from the buffer, not read back from the register: on
           ;; Windows the clipboard reads as empty while Emacs itself owns it.
           (text (if (eq type 'block)
                     (string-join (extract-rectangle beg end) "\n")
                   (buffer-substring-no-properties beg end))))
      (evil-yank beg end type curse-yank-register)
      (evil-exit-visual-state)
      (unless (string-empty-p text)
        (curse--flash beg end)
        (curse--report (cons (curse--describe text type) nil)
                       '(" yanked to " . font-lock-comment-face)
                       (cons (format "\"%c" curse-yank-register) 'curse-echo))))))

(defun curse--drag-yank-a (start-event)
  "After a drag or a triple click leaves a selection, yank it.
A double click is left alone: its own binding lights up occurrences."
  (when (and curse-mode (evil-visual-state-p) (not (curse--ignored-p)))
    (pcase (event-click-count start-event)
      (1 (curse-yank))
      (3
       ;; The double click before a triple click lit up occurrences nobody
       ;; asked for; take them away again. Evil does not reliably turn a
       ;; triple click into a line selection, so make it one here.
       (curse--occurrences-clear)
       (evil-visual-select (line-beginning-position) (line-end-position) 'line)
       (curse-yank)))))

;;; Occurrences

(defvar curse--occurrences nil
  "The lit-up name: (:buffer :word :overlays).")

(defvar curse--occurrences-token 0)

(defun curse--occurrences-clear (&rest _)
  (cl-incf curse--occurrences-token)
  (when curse--occurrences
    (mapc #'delete-overlay (plist-get curse--occurrences :overlays))
    (setq curse--occurrences nil)))

(defun curse--scan (word)
  "Whole-symbol matches of WORD in the buffer, for buffers with no server."
  (let ((case-fold-search nil) regions)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward (concat "\\_<" (regexp-quote word) "\\_>") nil t)
        (push (list (match-beginning 0) (match-end 0) 'curse-occurrence) regions)))
    (nreverse regions)))

(defun curse--occurrences-set (buffer word regions exact)
  (with-current-buffer buffer
    (setq curse--occurrences
          (list :buffer buffer :word word
                :overlays (mapcar (pcase-lambda (`(,beg ,end ,face))
                                    (let ((overlay (make-overlay beg end)))
                                      (overlay-put overlay 'face face)
                                      (overlay-put overlay 'priority 120)
                                      overlay))
                                  regions))))
  (curse--report (cons word 'curse-occurrence)
                 (cons (concat "  " (curse--plural (length regions) "occurrence")) nil)
                 (cons (if exact "" "   text match, no server") 'font-lock-comment-face)))

(defun curse-occurrences ()
  "Light up every occurrence of the symbol at point.
Asked again on the same name, put them away."
  (interactive)
  (unless (curse--ignored-p)
    (let ((word (car (curse--symbol-at (point))))
          (buffer (current-buffer)))
      (cond
       ((not word) (curse--occurrences-clear))
       ((and curse--occurrences
             (eq (plist-get curse--occurrences :buffer) buffer)
             (equal (plist-get curse--occurrences :word) word))
        (curse--occurrences-clear)
        (curse--report (cons word 'curse-occurrence)
                       '("  highlights cleared" . font-lock-comment-face)))
       (t
        (curse--occurrences-clear)
        (let ((token curse--occurrences-token))
          (if (not (curse--lsp-p "textDocument/documentHighlight"))
              (curse--occurrences-set buffer word (curse--scan word) nil)
            (lsp-request-async
             "textDocument/documentHighlight"
             (lsp--text-document-position-params)
             (lambda (highlights)
               (when (and (= token curse--occurrences-token) (buffer-live-p buffer))
                 (with-current-buffer buffer
                   (let ((regions
                          (mapcar (lambda (highlight)
                                    (let ((region (lsp--range-to-region
                                                   (lsp:document-highlight-range highlight))))
                                      (list (car region) (cdr region)
                                            (if (eql (lsp:document-highlight-kind? highlight) 3)
                                                'curse-occurrence-write
                                              'curse-occurrence))))
                                  highlights)))
                     ;; Some servers decline on keywords. An empty answer
                     ;; falls back to the scan, so the gesture never feels dead.
                     (if regions
                         (curse--occurrences-set buffer word regions t)
                       (curse--occurrences-set buffer word (curse--scan word) nil))))))
             :mode 'tick))))))))

(defun curse-double-click (event)
  "Double click: light up the name under the pointer."
  (interactive "e")
  (cl-incf curse--peek-token)
  (curse-peek-close)
  (when (evil-visual-state-p)
    (evil-exit-visual-state))
  (let ((target (curse--target event)))
    (if (not (plist-get target :on-text))
        (curse--occurrences-clear)
      (select-window (plist-get target :window))
      (goto-char (plist-get target :pos))
      (curse-occurrences))))

(defun curse--leave-check (&rest _)
  "Occurrences do not outlive leaving their buffer."
  (when (and curse--occurrences
             (not (window-minibuffer-p (selected-window)))
             (not (eq (window-buffer (selected-window))
                      (plist-get curse--occurrences :buffer))))
    (curse--occurrences-clear)))

;;; Moving around

(defun curse--focus-pointer (event)
  "Move to where EVENT points; nil when it points at nothing readable."
  (when-let* ((target (curse--target event)))
    (select-window (plist-get target :window))
    (goto-char (plist-get target :pos))
    target))

(defun curse--word ()
  (or (car (curse--symbol-at (point))) "this position"))

(defun curse--present (items word noun)
  "Go to a lone ITEM, or list several; either way, say which happened."
  (cond
   ((null items)
    (curse--report (cons word 'curse-echo)
                   (cons (format "  no %ss found" noun) 'font-lock-comment-face)))
   ((and (null (cdr items)) curse-jump-to-single)
    (xref-pop-to-location (car items))
    (recenter)
    (curse--report (cons word 'curse-echo)
                   (cons (concat "  " (curse--here)) nil)
                   ;; One definition is the ordinary case. One reference means
                   ;; the list you expected did not open, so say why.
                   (cons (if (equal noun "reference") "   the only reference" "")
                         'font-lock-comment-face)))
   (t
    (curse--report (cons word 'curse-echo)
                   (cons (concat "  " (curse--plural (length items) noun)) nil))
    (lsp-show-xrefs items nil (equal noun "reference")))))

(defun curse-definition (&optional event)
  "Go to the definition of the symbol at point, or under the pointer."
  (interactive (list last-nonmenu-event))
  (when (or (not (mouse-event-p event)) (curse--focus-pointer event))
    (let ((word (curse--word)))
      (evil-set-jump)
      (if (curse--lsp-p "textDocument/definition")
          (lsp-request-async "textDocument/definition"
                             (lsp--text-document-position-params)
                             (lambda (locations)
                               (curse--present (lsp--locations-to-xref-items locations)
                                               word "definition"))
                             :mode 'detached)
        ;; No server. Neovim tries a tags file; Doom's lookup tries every
        ;; other backend it has. Failing both, say so rather than seem broken.
        (let ((buffer (current-buffer))
              (pos (point)))
          (ignore-errors (call-interactively #'+lookup/definition))
          (if (and (eq buffer (current-buffer)) (= pos (point)))
              (curse--report (cons word 'curse-echo)
                             '("  no definition provider here" . font-lock-comment-face))
            (curse--report (cons word 'curse-echo)
                           (cons (concat "  " (curse--here)) nil)
                           '("   lookup, no server" . font-lock-comment-face))))))))

(defun curse-references (&optional event)
  "List every reference to the symbol at point, or under the pointer."
  (interactive (list last-nonmenu-event))
  (when (or (not (mouse-event-p event)) (curse--focus-pointer event))
    (let ((word (curse--word)))
      (if (not (curse--lsp-p "textDocument/references"))
          (curse--report (cons word 'curse-echo)
                         '("  no reference provider here" . font-lock-comment-face))
        (evil-set-jump)
        (lsp-request-async "textDocument/references"
                           (append (lsp--text-document-position-params)
                                   '(:context (:includeDeclaration t)))
                           (lambda (locations)
                             (curse--present (lsp--locations-to-xref-items locations)
                                             word "reference"))
                           :mode 'detached)))))

(defun curse--jump (direction)
  (let ((label (if (< direction 0) "back" "forward"))
        (buffer (current-buffer))
        (pos (point)))
    (ignore-errors
      (if (< direction 0) (evil-jump-backward) (evil-jump-forward)))
    ;; The jump list ends quietly. Say so, rather than leave a dead button.
    (if (and (eq buffer (current-buffer)) (= pos (point)))
        (curse--report (cons label 'curse-echo)
                       (cons (format "  nothing to jump %s to" label) 'font-lock-comment-face))
      (curse--report (cons label 'curse-echo) (cons (concat "  " (curse--here)) nil)))))

(defun curse-jump-back ()
  "Walk the jump list back, like a browser's back button."
  (interactive)
  (curse--jump -1))

(defun curse-jump-forward ()
  "Walk the jump list forward, like a browser's forward button."
  (interactive)
  (curse--jump 1))

(defun curse-copy-location ()
  "Copy path:line for point, the piece of a file everybody retypes by hand."
  (interactive)
  (if (not buffer-file-name)
      (curse--report '("this buffer has no file" . font-lock-comment-face))
    (let ((location (curse--here)))
      (evil-set-register curse-yank-register location)
      (curse--report (cons location nil)
                     '(" yanked to " . font-lock-comment-face)
                     (cons (format "\"%c" curse-yank-register) 'curse-echo)))))

(defun curse-rename ()
  "Rename the symbol at point through the language server."
  (interactive)
  (let ((old (curse--word)))
    (if (not (curse--lsp-p "textDocument/rename"))
        (curse--report (cons old 'curse-echo)
                       '("  no rename provider here" . font-lock-comment-face))
      ;; Curse asks for the name itself, so it has something to report.
      (let ((new (read-string (format "Rename %s to: " old) old)))
        (unless (or (string-empty-p new) (equal new old))
          (lsp-rename new)
          (curse--report (cons old 'curse-echo)
                         '("  renamed to  " . font-lock-comment-face)
                         (cons new 'curse-echo)))))))

(defun curse-code-action ()
  "Offer the language server's code actions for point or the selection."
  (interactive)
  (if (curse--lsp-p "textDocument/codeAction")
      (call-interactively #'lsp-execute-code-action)
    (curse--report (cons (curse--word) 'curse-echo)
                   '("  no code action provider here" . font-lock-comment-face))))

(defun curse-clear ()
  "Put away the peek float and the lit-up occurrences."
  (interactive)
  (curse--occurrences-clear)
  (curse-peek-close)
  (curse--report '("cleared" . font-lock-comment-face)))

;;; Right-click menu

(defun curse--context-menu (menu click)
  "Put Curse's items at the top of MENU, as Neovim's PopUp menu has them."
  (when (and curse-mode
             (not (curse--ignored-p (window-buffer (posn-window (event-start click))))))
    (let ((items (if (evil-visual-state-p)
                     '(("Yank to clipboard" . curse-yank)
                       ("Code action" . curse-code-action))
                   '(("Peek symbol" . curse-peek)
                     ("Occurrences" . curse-occurrences)
                     ("Find references" . curse-references)
                     ("Rename symbol" . curse-rename)
                     ("Code action" . curse-code-action)
                     ("Copy location" . curse-copy-location)))))
      ;; Each `define-key' of a new item lands at the top, so go bottom up.
      (define-key menu [curse-separator] menu-bar-separator)
      (dolist (item (reverse items))
        (define-key menu (vector (cdr item)) (list 'menu-item (car item) (cdr item))))))
  menu)

(defun curse-context-menu (event)
  "Right click: point to the pointer, then the context menu."
  (interactive "e")
  (unless (evil-visual-state-p)
    (mouse-set-point event))
  (popup-menu (context-menu-map event) event))

;;; Status and the mode

(defun curse-status ()
  "Say whether Curse is on, and which gestures it binds."
  (interactive)
  (message "%s"
           (concat (propertize "curse" 'face 'curse-echo)
                   (if curse-mode "  active" "  inactive")
                   (propertize "
  click peek · drag yank · double click occurrences · C-click definition
  S-click references · C-right click back · thumbs back/forward · right click menu"
                               'face 'font-lock-comment-face))))

(define-minor-mode curse-mode
  "Mouse gestures for Evil's Normal state. See lisp/curse.el."
  :global t
  :group 'curse
  (if curse-mode
      (progn
        (advice-add 'evil-mouse-drag-region :after #'curse--drag-yank-a)
        (add-hook 'evil-insert-state-entry-hook #'curse--occurrences-clear)
        (add-hook 'window-buffer-change-functions #'curse--leave-check)
        (add-hook 'window-selection-change-functions #'curse--leave-check)
        (add-hook 'context-menu-functions #'curse--context-menu 90))
    (advice-remove 'evil-mouse-drag-region #'curse--drag-yank-a)
    (remove-hook 'evil-insert-state-entry-hook #'curse--occurrences-clear)
    (remove-hook 'window-buffer-change-functions #'curse--leave-check)
    (remove-hook 'window-selection-change-functions #'curse--leave-check)
    (remove-hook 'context-menu-functions #'curse--context-menu)
    (curse-peek-close)
    (curse--occurrences-clear)))

;; Normal (and Motion) state only, so Insert state keeps every click Emacs
;; gives it. The down events are claimed too, or Emacs's buffer menu (C-click)
;; and font menu (S-click) would open first.
(evil-define-minor-mode-key '(normal motion) 'curse-mode
  [mouse-1] #'curse-click
  [C-down-mouse-1] #'ignore
  [C-mouse-1] #'curse-definition
  [S-down-mouse-1] #'ignore
  [S-mouse-1] #'curse-references
  [C-down-mouse-3] #'ignore
  [C-mouse-3] #'curse-jump-back)

(evil-define-minor-mode-key '(normal motion visual) 'curse-mode
  ;; Visual too: Evil selects the word on the second press, and looks up
  ;; what the release is bound to while that selection is live.
  [double-mouse-1] #'curse-double-click
  [down-mouse-3] #'curse-context-menu
  [mouse-3] #'ignore
  ;; Windows reports the thumb buttons as the fourth and fifth mouse buttons;
  ;; X and macOS number them eight and nine.
  [mouse-4] (if (eq system-type 'windows-nt) #'curse-jump-back nil)
  [mouse-5] (if (eq system-type 'windows-nt) #'curse-jump-forward nil)
  [mouse-8] #'curse-jump-back
  [mouse-9] #'curse-jump-forward)

(provide 'curse)
