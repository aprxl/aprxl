; extends

; Groselha's own Rust captures. Every pattern here re-captures a node that the
; upstream query already named, so it wins by coming later.

; `unsafe` is the one word Groselha sets in bold, and no upstream query gives it
; a capture of its own.
"unsafe" @keyword.unsafe

; Upstream calls every assert a hazard, which turns a test file into bold soup.
; An assert is an ordinary macro; what aborts outright is the panic family.
((macro_invocation
  macro: (identifier) @_name @function.macro
  "!" @function.macro)
  (#contains? @_name "assert"))

((macro_invocation
  macro: (identifier) @_name @keyword.exception
  "!" @keyword.exception)
  (#any-of? @_name "panic" "unreachable" "todo" "unimplemented"))

; A declared name is ink — the declaration states the type in the accent already,
; and the name adds nothing there. Upstream reads a SCREAMING_CASE static as a
; constant, so the accent has to be taken back off it.
(static_item
  name: (identifier) @variable)

; An attribute is meta from `#` to `]`. Upstream splits it into a macro name,
; a special `#`, plain brackets and loose identifiers. String and number
; literals inside keep their own captures, so values still read as values.
(attribute_item
  [
    "#"
    "["
    "]"
  ] @attribute)

(inner_attribute_item
  [
    "#"
    "!"
    "["
    "]"
  ] @attribute)

((identifier) @attribute
  (#has-ancestor? @attribute attribute_item inner_attribute_item))

([
  "("
  ")"
  "::"
] @attribute
  (#has-ancestor? @attribute attribute_item inner_attribute_item))

; Upstream sets a lifetime's quote as a keyword and its name as an attribute;
; `'a` is one annotation.
(lifetime
  "'" @attribute)

; `const` and `dyn` qualify a type. Upstream files them with `pub` and `mut`,
; which are visibility and binding rather than type.
[
  "const"
  "dyn"
] @keyword.type
