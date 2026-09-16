;;; config.el -*- lexical-binding: t; -*-
;;
;; Port of April's Neovim configuration. Section order mirrors the source:
;; options.lua, then keymaps.lua, then packages.lua. Additions with no Neovim
;; counterpart come last.

;;; --------------------------------------------------------------- options.lua

(setq user-full-name "April")

;; Berkeley Mono (Nerd Font patch), already installed system-wide.
;;
;; The family name really is cut off at 31 characters. Windows GDI caps family
;; names there and Emacs inherits the cap, so `font-family-list' reports
;; exactly this string. Do not "fix" it to ...Font Mono -- this spelling is
;; what Emacs actually enumerates.
(setq doom-font (font-spec :family "BerkeleyMonoExtra Nerd Font Mon" :size 18))

;; Icons come from the same font. nerd-icons (tabs, modeline, completion) and
;; Doom's fontset both ask for "Symbols Nerd Font Mono", which is not installed
;; here, so every icon fell back to a hex box. Berkeley Mono's Nerd Font patch
;; carries the same glyphs. Doom runs `after-setting-font-hook' right after it
;; claims the Private Use Area, so this hook gets the last word.
;; Emacs 31 on Windows already shapes text with HarfBuzz and draws it with
;; DirectWrite, so there is no older renderer left to switch away from. What
;; differs from Windows Terminal is antialiasing: the terminal smooths this font
;; in grayscale, while Emacs defaults to full ClearType and its colour fringes.
;; The arguments are enhanced contrast, ClearType level and gamma; nil keeps a default.
(when (and (fboundp 'w32-dwrite-available) (w32-dwrite-available))
  (w32-dwrite-reinit nil 0.0))

(setq nerd-icons-font-family "BerkeleyMonoExtra Nerd Font Mon")
(add-hook! 'after-setting-font-hook
  (defun +nerd-icons-fontset-h ()
    (dolist (range '((#xe000 . #xf8ff) (#xf0000 . #xfffff)))
      (set-fontset-font t range nerd-icons-font-family))))

;; Groselha Breu, as in Neovim. ./themes holds groselha (Papel) and
;; groselha-breu plus the seven Guara variants; `guara' below switches between
;; those the way :Guara does.
(setq doom-theme 'groselha-breu)

;; nvim-treesitter's queries plus the after/queries corrections, run by Emacs,
;; so C, C++ and Rust are classified the way Neovim classifies them and the
;; themes get the captures they were written for.
(load! "lisp/ts-queries")

;; Neovim 0.12 turns semantic tokens on by default, and both theme families
;; colour statics, globals and constants through them.
(after! lsp-mode
  (setq lsp-semantic-tokens-enable t))
(load! "lisp/lsp-semantic")

(defconst +guara-variants
  '("light" "noir" "epaper-light" "epaper-noir" "artpiece-fantasy" "artpiece-urushi" "sono")
  "Guara variants, as :Guara names them.")

(defun guara (variant)
  "Switch to the Guara VARIANT, like :Guara in Neovim."
  (interactive (list (completing-read "Guara variant: " +guara-variants nil t)))
  (let ((theme (if (equal variant "light") 'guara (intern (concat "guara-" variant)))))
    (mapc #'disable-theme custom-enabled-themes)
    (setq doom-theme theme)
    (load-theme theme t)))

;; The theme picker, Telescope-style. SPC h t (and M-x load-theme, which Doom
;; points at consult-theme) opens a floating list in the middle of the frame:
;; moving through it previews each theme live, RET keeps the one shown, and
;; C-g puts the old one back. Guara and Groselha come first.
(defun +theme-picker-sort (candidates)
  "Guara and Groselha first, then every other theme; each group A to Z."
  (let ((ours (lambda (name) (string-match-p "\\`\\(?:guara\\|groselha\\)" name))))
    (append (sort (seq-filter ours candidates) #'string<)
            (sort (seq-remove ours candidates) #'string<))))

;; M-x load-theme skips Doom's remap (remaps apply to keys, not to M-x), and
;; plain `load-theme' stacks the new theme on the old ones, mixing their colours.
;; Once a theme has loaded from M-x, switch every other one off. This runs
;; after loading, so answering "no" to the safety question keeps what was there.
(defun +load-theme-alone-a (theme &optional _no-confirm no-enable)
  (when (and (eq this-command 'load-theme)
             (not no-enable)
             (memq theme custom-enabled-themes))
    (mapc #'disable-theme (remq theme custom-enabled-themes))))
(advice-add 'load-theme :after #'+load-theme-alone-a)

(after! consult
  ;; Doom previews after half a second or on C-SPC; a fifth of a second keeps
  ;; up with holding C-n without loading every theme on the way past.
  (consult-customize consult-theme :preview-key '("C-SPC" :debounce 0.2 any)))

(after! vertico-multiform
  (when (require 'vertico-posframe nil t)
    (setq vertico-posframe-width 60
          vertico-posframe-border-width 1)
    (add-to-list 'vertico-multiform-commands
                 '(consult-theme posframe
                                 (vertico-sort-function . +theme-picker-sort)))))

;; opt.number + opt.relativenumber
(setq display-line-numbers-type 'relative)

;; options.lua: relativenumber goes away in Insert and comes back on leave.
;; Buffers that show no line numbers at all are left alone.
(defun +numbers-absolute-h ()
  (when display-line-numbers (setq display-line-numbers t)))
(defun +numbers-relative-h ()
  (when display-line-numbers (setq display-line-numbers 'relative)))
(add-hook 'evil-insert-state-entry-hook #'+numbers-absolute-h)
(add-hook 'evil-insert-state-exit-hook  #'+numbers-relative-h)

;; opt.wrap = false
(setq-default truncate-lines t)

;; opt.expandtab / shiftwidth / tabstop
(setq-default indent-tabs-mode nil
              tab-width 2)
(setq evil-shift-width 2)

;; opt.scrolloff / opt.sidescrolloff
(setq scroll-margin 5
      hscroll-margin 8)

;; opt.backup / writebackup / swapfile off. :emacs undo covers opt.undofile.
(setq make-backup-files nil
      create-lockfiles nil
      auto-save-default nil)

;; opt.autoread, plus the FileChangedShellPost notification.
(setq global-auto-revert-non-file-buffers t
      auto-revert-verbose t)
(global-auto-revert-mode 1)

;; opt.timeoutlen 400 / which-key delay 300
(setq which-key-idle-delay 0.3)

;; opt.guicursor = "a:block" -- a solid block in every state.
(setq evil-normal-state-cursor   'box
      evil-insert-state-cursor   'box
      evil-visual-state-cursor   'box
      evil-replace-state-cursor  'box
      evil-operator-state-cursor 'box
      evil-motion-state-cursor   'box
      evil-emacs-state-cursor    'box)
(blink-cursor-mode -1)

;; formatoptions -= c,r,o : never continue a comment onto the next line.
(setq +evil-want-o/O-to-continue-comments nil)

;; vim.diagnostic.config: virtual_text = false, severity_sort = true.
(after! flycheck
  (setq flycheck-display-errors-function nil
        flycheck-indication-mode 'left-fringe))

;; The closest stock stand-in for options.lua's debounced hovering diagnostic.
;; It sits on the line rather than pinned top-right; the real thing is Tier 2.
(after! lsp-ui
  (setq lsp-ui-sideline-enable t
        lsp-ui-sideline-show-diagnostics t
        lsp-ui-sideline-show-hover nil
        lsp-ui-sideline-show-code-actions nil
        lsp-ui-sideline-delay 0.35
        lsp-ui-doc-enable nil))

;;; --------------------------------------------------------------- keymaps.lua

;; Already Doom defaults, so they are not rebound below:
;;   SPC SPC  files      SPC f r  recent files
;;   gd       definition SPC c a  code action
;;
;; SPC w and SPC x x displace Doom's window prefix and its scratch-buffer key.
;; That is deliberate -- it keeps the Neovim muscle memory. Window management
;; is still on C-w, exactly as in Vim.
;;
;; Emacs will not hang a prefix under a key that is already a command, and Doom
;; binds SPC x and SPC r to commands. Binding SPC x x on top of a live SPC x
;; signals an error that aborts the rest of this file, so clear both first.
(map! :leader "x" nil "r" nil)

(map! :leader
      :desc "Search text"   "/"   #'+default/search-project
      :desc "Next buffer"   "w"   #'next-buffer
      :desc "Pick buffer"   "W"   #'consult-buffer
      :desc "Diagnostics"   "x x" #'+default/diagnostics
      :desc "Rename symbol" "r n" #'lsp-rename)

(map! :n "gr"  #'+lookup/references
      :n "C-k" #'+lookup/documentation)

;; flash.nvim: `s` then a character labels every match. Doom gives `s` to
;; evil-snipe, so snipe has to let go of it first.
;;
;; Switching the mode off here is not enough. Doom enables it from
;; `doom-first-input-hook', which fires later and would turn it straight back
;; on; taking it off that hook is the documented way out.
(remove-hook 'doom-first-input-hook #'evil-snipe-mode)
(remove-hook 'doom-first-input-hook #'evil-snipe-override-mode)
(after! avy
  (setq avy-timeout-seconds 0.4))
(map! :nv "s" #'evil-avy-goto-char-timer
      :o  "s" #'evil-avy-goto-char-timer)

;; keymaps.lua: strictly pace repeated j/k. The first press responds
;; immediately, then each subsequent motion needs a 117 ms gap. Excess repeats
;; are dropped, never buffered.
(defvar +motion-throttle-interval 0.117)
(defvar +motion-throttle--last 0)
(defun +motion-throttle-a (fn &rest args)
  (if (not (memq this-command '(evil-next-line evil-previous-line)))
      (apply fn args)
    (let ((now (float-time)))
      (when (>= (- now +motion-throttle--last) +motion-throttle-interval)
        (setq +motion-throttle--last now)
        (apply fn args)))))
(advice-add #'evil-next-line     :around #'+motion-throttle-a)
(advice-add #'evil-previous-line :around #'+motion-throttle-a)

;;; -------------------------------------------------------------- packages.lua

;; bufferline.nvim
(after! centaur-tabs
  (setq centaur-tabs-style "bar"
        centaur-tabs-set-bar 'left
        centaur-tabs-set-icons t
        centaur-tabs-set-modified-marker t
        centaur-tabs-modified-marker "*"
        centaur-tabs-show-navigation-buttons nil
        centaur-tabs-cycle-scope 'tabs))

;; lualine.nvim, redesigned into a fuller line; see lisp/statusline.el.
;; Buffer names still live in the tab bar, as they do under bufferline.
(after! doom-modeline
  (load! "lisp/statusline"))

;; nvim-lspconfig: clangd's arguments, verbatim from packages.lua.
(after! lsp-clangd
  (setq lsp-clients-clangd-args '("--background-index" "--clang-tidy")))

;; mini.cursorword -- lsp-mode's documentHighlight already does this, and it
;; knows a symbol from a string, which mini.cursorword did not.
;;
;; vim.lsp.enable picks a root from markers (.git, compile_commands.json, ...)
;; without asking. lsp-mode instead stops on the first file of every new tree
;; to ask "a.c is not part of any project"; guess silently from projectile and
;; project.el instead. A file outside any project falls back to its own
;; directory as the root, much like Neovim's single-file mode. The one sharp
;; edge: a loose file sitting directly in ~ makes ~ the root, and some servers
;; (lua-language-server among them) will then try to scan all of it.
(after! lsp-mode
  (setq lsp-enable-symbol-highlighting t
        lsp-idle-delay 0.35
        lsp-signature-auto-activate nil
        lsp-auto-guess-root t))

;; blink.cmp: menu after 500 ms, no auto-brackets, docs only on demand.
(after! corfu
  (setq corfu-preselect 'first
        corfu-popupinfo-delay nil))   ; documentation.auto_show = false

;; The auto-popup delay lives in Doom's `corfu-auto' package, which loads after
;; `corfu' itself. Set it inside (after! corfu ...) and Doom's own :config runs
;; afterwards and puts it back to 0.24.
(after! corfu-auto
  (setq corfu-auto t
        corfu-auto-delay 0.5          ; blink.cmp auto_show_delay_ms = 500
        corfu-auto-prefix 2))
(map! :after corfu
      :map corfu-map
      "TAB"     #'corfu-next
      [tab]     #'corfu-next
      "S-TAB"   #'corfu-previous
      [backtab] #'corfu-previous
      "C-k"     #'corfu-popupinfo-toggle
      "C-e"     #'corfu-quit)

;; packages.lua: Rust always formats on save; C and C++ format only inside a
;; project that actually ships a .clang-format, so foreign trees stay untouched.
;;
;; This vetoes apheleia's global mode instead of switching apheleia-mode off
;; from a major-mode hook: the global mode turns buffers on after those hooks
;; have run, so a hook that turns it off is simply overruled.
(defun +cc-format-without-clang-format-p ()
  "Non-nil in a C-family buffer with no .clang-format above its file."
  (and (derived-mode-p '(c-mode c++-mode c-ts-mode c++-ts-mode objc-mode))
       (not (and buffer-file-name
                 (locate-dominating-file buffer-file-name ".clang-format")))))
(add-hook 'apheleia-inhibit-functions #'+cc-format-without-clang-format-p)

;; apheleia applies a formatter's output as a patch that it makes with `diff',
;; so every save ended in "Failed to run diff": Windows has no diff, and the
;; PATH Emacs gets from the Start menu holds only Git's cmd folder. Git ships
;; diff in its usr/bin, next to that cmd folder. That directory goes at the end
;; of `exec-path', so Windows' own find and sort still come first.
(defun +git-unix-tools-dir ()
  "Git for Windows' usr/bin, if it holds a diff.exe."
  (let ((git (executable-find "git")))
    (seq-find (lambda (dir) (and dir (file-executable-p (expand-file-name "diff.exe" dir))))
              (list (and git (expand-file-name "../usr/bin" (file-name-directory git)))
                    (expand-file-name "~/scoop/apps/git/current/usr/bin")
                    "C:/Program Files/Git/usr/bin"))))

(when (and (eq system-type 'windows-nt) (not (executable-find "diff")))
  (when-let* ((dir (+git-unix-tools-dir)))
    (add-to-list 'exec-path dir t)))

;; nvim-treesitter: packages.lua's treesitter_languages, verbatim.
;;
;; Doom already ships grammar recipes for about 75 languages, so this only
;; names the subset the Neovim config builds; replacing the recipe list would
;; strip every other language's ability to fetch one.
(defvar +treesit-languages '(c cpp rust lua zig)
  "Parsers from packages.lua's treesitter_languages.")

;; Emacs's grammar builder looks only for cc, gcc or c99 (and c++ or g++). On a
;; machine with LLVM and nothing else -- this one -- it falls through to a bare
;; `cc' that does not exist, and every build fails. Name clang in any recipe
;; that leaves the compiler unset; where cc exists this does nothing.
(defun +treesit-prefer-clang ()
  (when (and (not (executable-find "cc")) (executable-find "clang"))
    (setq treesit-language-source-alist
          (mapcar
           (lambda (recipe)
             (let ((spec (copy-sequence (cdr recipe))))
               (if (keywordp (cadr spec))
                   ;; (LANG URL :keyword value ...)
                   (let ((plist (cdr spec)))
                     (unless (plist-member plist :cc)
                       (setq plist (plist-put plist :cc "clang")))
                     (unless (plist-member plist :c++)
                       (setq plist (plist-put plist :c++ "clang++")))
                     (cons (car recipe) (cons (car spec) plist)))
                 ;; (LANG URL REVISION SOURCE-DIR CC C++ COMMIT)
                 (when (< (length spec) 5)
                   (setq spec (append spec (make-list (- 5 (length spec)) nil))))
                 (setf (nth 3 spec) (or (nth 3 spec) "clang")
                       (nth 4 spec) (or (nth 4 spec) "clang++"))
                 (cons (car recipe) spec))))
           treesit-language-source-alist))))
(after! treesit
  (+treesit-prefer-clang)
  ;; The builder also passes -fPIC to every compile step, and clang rejects
  ;; that flag outright for Windows (MSVC) targets. -fPIC means nothing for a
  ;; Windows DLL, which is relocated through its base-relocation table instead,
  ;; so dropping it loses nothing. Only the argument list is touched, and only
  ;; on Windows.
  (when (eq system-type 'windows-nt)
    (defadvice! +treesit-drop-fpic-a (args)
      :filter-args #'treesit--call-process-signal
      (remove "-fPIC" args))))

(defun +treesit-install-all ()
  "Build any grammar in `+treesit-languages' that is not present yet.
The Neovim config's :TSUpdate, more or less."
  (interactive)
  (require 'treesit)
  (+treesit-prefer-clang)
  (dolist (lang +treesit-languages)
    (if (treesit-language-available-p lang)
        (message "tree-sitter: %s already built" lang)
      (message "tree-sitter: building %s..." lang)
      (treesit-install-language-grammar lang))))

;; neoscroll.nvim, with its default mappings; see lisp/scroll-animate.el.
(after! evil
  (load! "lisp/scroll-animate")
  (scroll-animate-mode 1)
  (map! :nvm "C-e" #'scroll-animate-line-down
        :nvm "C-y" #'scroll-animate-line-up))

;; Curse, from ~/Develop/Curse: mouse gestures for Normal state; see
;; lisp/curse.el.
(after! evil
  (load! "lisp/curse")
  (curse-mode 1))

;;; ------------------------------------------------------ beyond the Neovim config

;; Splits, under SPC v. Each opens a new window to the right or below and moves
;; the cursor into it; which-key lists them after SPC v.
;;
;;   SPC v v  this file, right        SPC v t  terminal, right
;;   SPC v s  this file, below        SPC v T  terminal, below
;;
;; The file splits are C-w v and C-w s, except that the cursor follows the new
;; window instead of staying behind. Closing, resizing and moving between
;; splits stay on C-w.
;;
;; The terminal is ghostel (:term ghostel), a real terminal emulator on Windows'
;; ConPTY, so full-screen programs run in it. Each terminal split starts a new
;; shell in the project root, or in the buffer's directory outside a project.
;; Doom adds SPC o t for one toggling popup terminal and SPC o T for a terminal
;; in the current window.
(defun +split--terminal (split)
  "Run SPLIT, then start a new terminal in the window it selects.
If the terminal does not start, the new window closes again."
  (let ((default-directory (or (doom-project-root) default-directory)))
    (funcall split)
    (let ((window (selected-window)))
      (condition-case err
          (ghostel t)
        ((error quit)
         (delete-window window)
         (signal (car err) (cdr err)))))))

(defun +split/terminal-right ()
  "Open a new terminal in a split to the right."
  (interactive)
  (+split--terminal #'+evil/window-vsplit-and-follow))

(defun +split/terminal-below ()
  "Open a new terminal in a split below."
  (interactive)
  (+split--terminal #'+evil/window-split-and-follow))

(map! :leader
      (:prefix-map ("v" . "split")
       :desc "This file, right" "v" #'+evil/window-vsplit-and-follow
       :desc "This file, below" "s" #'+evil/window-split-and-follow
       :desc "Terminal, right"  "t" #'+split/terminal-right
       :desc "Terminal, below"  "T" #'+split/terminal-below))

;; ghostel runs $SHELL, which Windows does not set, so name the shell: Windows
;; PowerShell, the default profile in Windows Terminal on this machine.
(after! ghostel
  (when (eq system-type 'windows-nt)
    (setq ghostel-shell '("powershell.exe" "-NoLogo"))))

;; ghostel's native module is a DLL it downloads on first use. Keep it out of
;; Doom's package build tree: rebuilding a package deletes that tree, and
;; Windows refuses to delete a DLL that a running Emacs has loaded.
(setq ghostel-module-directory (file-name-concat doom-data-dir "ghostel/"))
