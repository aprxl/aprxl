;;; lisp/statusline.el -*- lexical-binding: t; -*-
;;
;; The statusline, grown from lualine's two facts into a balanced line:
;;
;;    NOR     main    2   1                        clangd   C++   342:8  21%
;;
;; - The mode sits in a rounded pill coloured by Evil state, as lualine colours
;;   its section a: the theme's accent in Normal state, the doom-modeline state
;;   colours otherwise. Labels are lualine's short ones (NOR, INS, V-LIN, ...).
;; - Then the git branch, and error and warning counts, with the same Nerd
;;   icons bufferline.nvim used; each shows only when there is something to say.
;; - On the right, dimmed: the attached language servers, the language, and
;;   the position, where line:column is the brightest thing on the line.
;; - No file name: the tab bar already shows it.
;; Inactive windows keep the layout, with every colour muted.

(require 'doom-modeline)

(setq doom-modeline-height 30)

(defface +statusline-muted '((t :inherit shadow))
  "Secondary statusline text.")

(defconst +statusline--state-faces
  '((insert . doom-modeline-evil-insert-state)
    (visual . doom-modeline-evil-visual-state)
    (replace . doom-modeline-evil-replace-state)
    (operator . doom-modeline-evil-operator-state)
    (motion . doom-modeline-evil-motion-state)
    (emacs . doom-modeline-evil-emacs-state))
  "Where each Evil state's pill colour comes from, Normal aside.")

(defun +statusline--label ()
  "lualine's short mode names."
  (pcase (bound-and-true-p evil-state)
    ('normal "NOR")
    ('insert (if (derived-mode-p 'ghostel-mode) "TER" "INS"))
    ('visual (pcase (bound-and-true-p evil-visual-selection)
               ('line "V-LIN")
               ('block "V-BLK")
               (_ "VIS")))
    ('replace "REP")
    ('operator "OPE")
    ('motion "MOT")
    ('emacs "EMA")
    (_ "---")))

(defun +statusline--color (active)
  (cond ((not active) (face-foreground 'mode-line-inactive nil t))
        ((eq (bound-and-true-p evil-state) 'normal)
         (face-background 'doom-modeline-bar nil t))
        (t (face-foreground (alist-get evil-state +statusline--state-faces
                                       'doom-modeline-evil-emacs-state)
                            nil t))))

(defvar +statusline--struts (make-hash-table :test #'equal)
  "Invisible images that give the line its height, by colour and height.")

(defun +statusline--strut (ground)
  "A 1px image in the GROUND colour, as tall as `doom-modeline-height'."
  (with-memoization (gethash (cons ground doom-modeline-height) +statusline--struts)
    (propertize " " 'display
                (create-image (format "P1\n1 %d\n%s\n" doom-modeline-height
                                      (make-string doom-modeline-height ?1))
                              'pbm t :foreground ground :background ground
                              :ascent 'center))))

(defun +statusline--pill (text color ground)
  "TEXT on a COLOR pill with rounded ends, sitting on GROUND."
  (concat (propertize "" 'face `(:foreground ,color :background ,ground))
          (propertize (concat " " text " ")
                      'face `(:foreground ,ground :background ,color :weight bold))
          (propertize "" 'face `(:foreground ,color :background ,ground))))

(defun +statusline--branch ()
  "The branch in `vc-mode', without the backend in front of it."
  (when (and vc-mode buffer-file-name)
    (replace-regexp-in-string "\\`[^:-]+[:-]" ""
                              (string-trim (substring-no-properties vc-mode)))))

(doom-modeline-def-segment +mode
  (let* ((active (doom-modeline--active))
         (ground (face-background (if active 'mode-line 'mode-line-inactive) nil t)))
    (concat (+statusline--strut ground)
            " "
            (+statusline--pill (+statusline--label) (+statusline--color active) ground))))

(doom-modeline-def-segment +vcs
  (when-let* ((branch (+statusline--branch)))
    (concat "   " (propertize (concat " " branch) 'face '+statusline-muted))))

(doom-modeline-def-segment +diagnostics
  (when (bound-and-true-p flycheck-mode)
    (let* ((active (doom-modeline--active))
           (counts (flycheck-count-errors flycheck-current-errors))
           (errors (or (alist-get 'error counts) 0))
           (warnings (or (alist-get 'warning counts) 0)))
      (concat
       (when (> errors 0)
         (concat "   " (propertize (format " %d" errors)
                                   'face (if active 'error '+statusline-muted))))
       (when (> warnings 0)
         (concat "   " (propertize (format " %d" warnings)
                                   'face (if active 'warning '+statusline-muted))))))))

(doom-modeline-def-segment +lsp
  (when (bound-and-true-p lsp-mode)
    (when-let* ((names (mapcar (lambda (workspace)
                                 (symbol-name (lsp--client-server-id
                                               (lsp--workspace-client workspace))))
                               (lsp-workspaces))))
      (concat (propertize (string-join names " ") 'face '+statusline-muted) "   "))))

(doom-modeline-def-segment +language
  (concat (propertize (car (split-string (format-mode-line mode-name) "/"))
                      'face '+statusline-muted)
          "   "))

(doom-modeline-def-segment +position
  (concat (propertize (format-mode-line "%l:%C")
                      'face (if (doom-modeline--active)
                                `(:foreground ,(face-foreground 'default nil t))
                              '+statusline-muted))
          "  "
          (propertize (format-mode-line "%p") 'face '+statusline-muted)
          "  "))

(doom-modeline-def-modeline '+april
  '(+mode +vcs +diagnostics)
  '(+lsp +language +position))

(defun +statusline-h ()
  (doom-modeline-set-modeline '+april 'default))

(add-hook 'doom-modeline-mode-hook #'+statusline-h)
(when (bound-and-true-p doom-modeline-mode)
  (+statusline-h))

(provide 'statusline)
