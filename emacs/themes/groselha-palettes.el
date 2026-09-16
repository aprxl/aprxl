;;; groselha-palettes.el --- Groselha colour data -*- lexical-binding: t; -*-
;;
;; Transcribed mechanically from lua/groselha/palette.lua in the Neovim config,
;; which stays the source of truth.
;;
;; Three inks and a four-rung tone ladder: t1 keywords, t2 functions, t3 body
;; text, t4 comments. The accent, gro, marks values, types and hazards.

(defconst groselha-palettes
  '(
    (papel
     :name "groselha"
     :dark nil
     :bg "#EFE4D2"
     :gro "#DB1A50"
     :t1 "#0D0E10"
     :t2 "#262930"
     :t3 "#393C46"
     :t4 "#7F838C"
     :gutter "#E7DAC4"
     :line "#E6D8C0"
     :chrome "#EADDC9"
     :float "#F4EBDC"
     :sel "#DFCFB4"
     :border "#D8C9B0"
     :ghost "#BFB39D")
    (breu
     :name "groselha-breu"
     :dark t
     :bg "#1C1F24"
     :gro "#F53D71"
     :t1 "#EFE4D2"
     :t2 "#D4C7B1"
     :t3 "#B8AC99"
     :t4 "#847B6D"
     :gutter "#17191E"
     :line "#272B33"
     :chrome "#17191E"
     :float "#23272E"
     :sel "#33394A"
     :border "#101216"
     :ghost "#4A4F58")
    )
  "Groselha palettes, one property list per variant.")

(provide 'groselha-palettes)
