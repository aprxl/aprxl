;;; lisp/scroll-animate.el -*- lexical-binding: t; -*-
;;
;; neoscroll.nvim with its default mappings, for Evil.
;;
;; Neovim animates these keys, linearly, with the cursor hidden:
;;
;;   C-u C-d   half a page, over 250 ms
;;   C-b C-f   a page, over 450 ms
;;   C-y C-e   a tenth of the window, over 100 ms; the cursor stays put
;;   zt zz zb  250 ms for every half window travelled
;;
;; How it moves:
;; - Each command still does its own work, instantly, so where it lands is
;;   always Evil's answer. The view is then put back where it was on screen,
;;   and a timer walks it to that answer a few pixels every frame, leaving
;;   Emacs free to take the next key.
;; - A scroll key pressed mid-flight starts from where the running animation
;;   was headed, and the view sets off for the new answer from wherever it is
;;   on screen. Mashing C-d speeds the scroll up; nothing snaps.
;; - Any other key stops the animation where the view is, so a j pressed
;;   mid-scroll moves from what is on screen rather than jumping ahead first.
;; - While the view moves, the cursor is hidden and rides along on the row it
;;   will end on, and `scroll-margin' is off, so redisplay never drags the view
;;   back to keep the cursor clear of the margin.
;;
;; The mouse wheel is not touched: Doom's :ui smooth-scroll (ultra-scroll)
;; already makes that pixel-smooth.

(require 'cl-lib)
(require 'evil)
(require 'pixel-scroll)

(defvar scroll-animate-durations
  '((evil-scroll-up . 0.25)
    (evil-scroll-down . 0.25)
    (evil-scroll-page-up . 0.45)
    (evil-scroll-page-down . 0.45)
    (scroll-animate-line-up . 0.1)
    (scroll-animate-line-down . 0.1)
    (evil-scroll-line-to-top . per-half-window)
    (evil-scroll-line-to-center . per-half-window)
    (evil-scroll-line-to-bottom . per-half-window))
  "Commands to animate, with the seconds each animation takes.
`per-half-window' is 0.25 s for every half window of travel, as
neoscroll's zt, zz and zb take.")

(defvar scroll-animate-frame (/ 1.0 120)
  "Seconds between animation frames. Emacs draws no faster than it can.")

(defvar scroll-animate--running nil
  "Non-nil while an animated command runs, so commands it calls stay instant.")

;;; Geometry

(defun scroll-animate--lines (from to)
  "Signed number of lines from line start FROM to line start TO."
  (if (< from to) (count-lines from to) (- (count-lines to from))))

(defun scroll-animate--seconds (command pixels window)
  (let ((duration (alist-get command scroll-animate-durations)))
    (if (eq duration 'per-half-window)
        (* 0.25 (/ (abs (/ pixels (float (default-line-height))))
                   (/ (window-body-height window) 2.0)))
      duration)))

(defun scroll-animate--point-at-row (window row column)
  "The position ROW lines into WINDOW's view, at COLUMN."
  (save-excursion
    (goto-char (window-start window))
    (forward-line row)
    (move-to-column column)
    (point)))

(defun scroll-animate--place-point (window state)
  "Put the hidden cursor on the row it will end on, in the view as it is now."
  (set-window-point window
                    (scroll-animate--point-at-row
                     window
                     (max 1 (min (plist-get state :row) (- (window-body-height window) 2)))
                     (plist-get state :column))))

;;; Starting and stopping

(defun scroll-animate--restore (state)
  "Give the buffer back its margin, partial lines and cursor."
  (pcase-dolist (`(,var ,local . ,value) (plist-get state :saved))
    (if local (set (make-local-variable var) value) (kill-local-variable var)))
  (when (fboundp 'evil-refresh-cursor)
    (evil-refresh-cursor)))

(defun scroll-animate--end (window)
  "Take WINDOW's animation off the clock; return its state, or nil."
  (when-let* ((state (and (window-live-p window) (window-parameter window 'scroll-animate))))
    (cancel-timer (plist-get state :timer))
    (set-window-parameter window 'scroll-animate nil)
    state))

(defun scroll-animate--finish (window)
  "End WINDOW's animation with the view exactly where it was going."
  (when-let* ((state (scroll-animate--end window)))
    (let ((buffer (plist-get state :buffer)))
      (when (eq (window-buffer window) buffer)
        (set-window-vscroll window 0 t)
        (set-window-start window (plist-get state :target))
        (set-window-point window (plist-get state :destination)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (scroll-animate--restore state))))))

(defun scroll-animate--stop (window)
  "End WINDOW's animation with the view where it is on screen.
The cursor steps clear of the scroll margin it is about to get back, so
redisplay has no reason to move the view."
  (when-let* ((state (scroll-animate--end window)))
    (let ((buffer (plist-get state :buffer)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          (when (eq (window-buffer window) buffer)
            ;; A view stopped part-way through a line loses that part as soon
            ;; as the next command moves point, so settle on the nearest whole
            ;; line now: half a line at most, instead of up to a whole one.
            (let ((vscroll (window-vscroll window t)))
              (when (> vscroll 0)
                (when (>= (* 2 vscroll) (default-line-height))
                  (set-window-start window (save-excursion
                                             (goto-char (window-start window))
                                             (forward-line 1)
                                             (point))))
                (set-window-vscroll window 0 t)))
            (let* ((margin (cddr (assq 'scroll-margin (plist-get state :saved))))
                   (height (window-body-height window))
                   (row (max (1+ margin) (min (plist-get state :row) (- height 2 margin)))))
              (set-window-point window (scroll-animate--point-at-row
                                        window row (plist-get state :column)))))
          (scroll-animate--restore state))))))

(defun scroll-animate--frame (window)
  "Move WINDOW's view one frame closer to where its animation is going."
  (let ((state (and (window-live-p window) (window-parameter window 'scroll-animate))))
    (cond
     ((null state))
     ((not (eq (window-buffer window) (plist-get state :buffer)))
      (scroll-animate--finish window))
     (t
      (let* ((progress (min 1.0 (/ (- (float-time) (plist-get state :begin))
                                   (plist-get state :duration))))
             (want (round (* progress (plist-get state :total))))
             (delta (- want (plist-get state :done))))
        (unless (zerop delta)
          (with-selected-window window
            ;; pixel-scroll's names follow the wheel: "down" moves the view
            ;; towards the end of the buffer.
            (if (> delta 0)
                (pixel-scroll-precision-scroll-down delta)
              (pixel-scroll-precision-scroll-up (- delta))))
          (plist-put state :done want))
        (if (>= progress 1.0)
            (scroll-animate--finish window)
          (with-current-buffer (window-buffer window)
            (scroll-animate--place-point window state))))))))

(defun scroll-animate--start (window state from-start from-vscroll target destination total seconds)
  "Animate WINDOW from FROM-START plus FROM-VSCROLL pixels to TARGET.
TOTAL is the signed distance in pixels. STATE is the running animation this
one replaces, if any."
  (unless state
    ;; First frame: hide the cursor, and free the margin and the partial lines
    ;; so redisplay never moves the view to suit the cursor.
    (setq state (list :buffer (current-buffer)
                      :saved (mapcar (lambda (var)
                                       (cons var (cons (local-variable-p var) (symbol-value var))))
                                     '(scroll-margin make-cursor-line-fully-visible cursor-type))))
    (setq-local scroll-margin 0
                make-cursor-line-fully-visible nil
                cursor-type nil))
  (when-let* ((timer (plist-get state :timer)))
    (cancel-timer timer))
  (set-window-start window from-start)
  (set-window-vscroll window from-vscroll t t)
  (setq state (list :target target
                    :destination destination
                    :row (count-lines target (save-excursion
                                                (goto-char destination)
                                                (line-beginning-position)))
                    :column (save-excursion (goto-char destination) (current-column))
                    :begin (float-time)
                    :duration (max seconds scroll-animate-frame)
                    :total total
                    :done 0
                    :timer nil
                    :buffer (plist-get state :buffer)
                    :saved (plist-get state :saved)))
  (set-window-parameter window 'scroll-animate state)
  (scroll-animate--place-point window state)
  (plist-put state :timer (run-at-time scroll-animate-frame scroll-animate-frame
                                       #'scroll-animate--frame window)))

(defun scroll-animate--around (command fn &rest args)
  "Run COMMAND's FN with ARGS from where any running animation is going,
then animate the view from where it is on screen to where FN left it."
  (if (or scroll-animate--running executing-kbd-macro)
      (apply fn args)
    (let* ((window (selected-window))
           (state (window-parameter window 'scroll-animate))
           (from-start (window-start window))
           (from-vscroll (window-vscroll window t))
           (from-point (point)))
      ;; Continue from where the running animation was headed.
      (when state
        (set-window-vscroll window 0 t)
        (set-window-start window (plist-get state :target))
        (goto-char (plist-get state :destination)))
      (condition-case err
          (let ((scroll-animate--running t))
            (apply fn args))
        (error
         ;; Nothing has moved on screen yet; put the view back as it was.
         (when state
           (set-window-start window from-start)
           (set-window-vscroll window from-vscroll t t)
           (goto-char from-point))
         (signal (car err) (cdr err))))
      (let* ((target (window-start window))
             (destination (point))
             (total (- (* (scroll-animate--lines from-start target) (default-line-height))
                       from-vscroll)))
        (cond
         ((/= total 0)
          (scroll-animate--start window state from-start from-vscroll target destination total
                                 (scroll-animate--seconds command total window)))
         (state
          (scroll-animate--finish window)))))))

(defun scroll-animate--pre-command-h ()
  "Any other command stops animations where the view is, so nothing snaps."
  (unless (assq this-command scroll-animate-durations)
    (dolist (window (window-list-1 nil 'nomini t))
      (when (window-parameter window 'scroll-animate)
        (scroll-animate--stop window)))))

;;; C-e and C-y, a tenth of the window

(defun scroll-animate--tenth ()
  (max 1 (round (* 0.1 (window-body-height)))))

(evil-define-command scroll-animate-line-down ()
  "Scroll the view down a tenth of the window, as neoscroll's C-e does.
The cursor stays where it is unless the view pushes it along."
  :repeat nil
  :keep-visual t
  (evil-scroll-line-down (scroll-animate--tenth)))

(evil-define-command scroll-animate-line-up ()
  "Scroll the view up a tenth of the window, as neoscroll's C-y does.
The cursor stays where it is unless the view pushes it along."
  :repeat nil
  :keep-visual t
  (evil-scroll-line-up (scroll-animate--tenth)))

(define-minor-mode scroll-animate-mode
  "Animate Evil's scroll commands the way neoscroll.nvim does."
  :global t
  :group 'evil
  (dolist (window (window-list-1 nil 'nomini t))
    (scroll-animate--finish window))
  (dolist (entry scroll-animate-durations)
    (let ((command (car entry)))
      (advice-remove command 'scroll-animate)
      (when scroll-animate-mode
        (advice-add command :around
                    (lambda (fn &rest args)
                      (apply #'scroll-animate--around command fn args))
                    '((name . scroll-animate))))))
  (if scroll-animate-mode
      (add-hook 'pre-command-hook #'scroll-animate--pre-command-h)
    (remove-hook 'pre-command-hook #'scroll-animate--pre-command-h)))

(provide 'scroll-animate)
