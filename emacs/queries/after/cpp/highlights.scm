; extends

; Groselha's own C++ captures, on top of after/queries/c (inherited).

; Contracts: what a function promises about itself. Bold, but on the keyword
; rung, so they carry weight without reading as a hazard. Upstream calls
; `noexcept` an exception keyword, which would make it groselha and bold — the
; hazard treatment, on half the functions in a header.
[
  "noexcept"
  "override"
  "final"
  "virtual"
] @keyword.contract

; A declared name is ink, here as anywhere else.
((field_declaration
  (storage_class_specifier) @_storage
  declarator: (field_identifier) @variable)
  (#any-of? @_storage "static" "thread_local"))

; ...unless the member is itself a constant.
((field_declaration
  [
    (type_qualifier)
    "constexpr"
  ] @_qualifier
  declarator: (field_identifier) @constant)
  (#any-of? @_qualifier "const" "constexpr"))

; The suffix of `10ms` or `"text"s` is part of the value; upstream calls it an
; operator.
(literal_suffix) @number

; `constexpr` and `decltype` describe a type; upstream files them with plain
; keywords like `friend` and `using`.
[
  "constexpr"
  "decltype"
] @keyword.type

; The `*` and `&` of a declaration are what make the type a pointer or a
; reference, so they read as part of it. Plain dereference and address-of stay
; on the body rung: those are operations, not types.
(pointer_declarator
  "*" @type)

(abstract_pointer_declarator
  "*" @type)

(reference_declarator
  [
    "&"
    "&&"
  ] @type)

(abstract_reference_declarator
  [
    "&"
    "&&"
  ] @type)
