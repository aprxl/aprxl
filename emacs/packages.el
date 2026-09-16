;;; packages.el -*- lexical-binding: t; -*-
;;
;; Child frames for Curse's peek float (lisp/curse.el), at the same pin Doom's
;; own :input chinese module uses.
(package! posframe :pin "ec0ec37c0d6397422a07def499e87591ca037af7")

;; A floating, centred completion window for the theme picker only (see
;; config.el), at the pin Doom's own (vertico +childframe) uses.
(package! vertico-posframe
  :recipe (:host github :repo "tumashu/vertico-posframe")
  :pin "d6e06a4f1b34d24cc0ca6ec69d2d6c965191b23e")
