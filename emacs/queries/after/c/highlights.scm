; extends

; Groselha's own C captures. C++ inherits this file along with the upstream C
; query, so every pattern here must also hold for C++.

; A declared name is ink. The declaration states the type in the accent already,
; so the name adds nothing there, and upstream would read a SCREAMING_CASE one as
; a constant. Only declarators that name storage match: a function prototype's
; declarator is a function_declarator.
((declaration
  declarator: [
    (identifier) @variable
    (pointer_declarator
      declarator: (identifier) @variable)
    (array_declarator
      declarator: (identifier) @variable)
    (init_declarator
      declarator: [
        (identifier) @variable
        (pointer_declarator
          declarator: (identifier) @variable)
        (array_declarator
          declarator: (identifier) @variable)
      ])
  ]) @_declaration
  (#has-parent? @_declaration translation_unit declaration_list))

((declaration
  (storage_class_specifier) @_storage
  declarator: [
    (identifier) @variable
    (pointer_declarator
      declarator: (identifier) @variable)
    (array_declarator
      declarator: (identifier) @variable)
    (init_declarator
      declarator: [
        (identifier) @variable
        (pointer_declarator
          declarator: (identifier) @variable)
        (array_declarator
          declarator: (identifier) @variable)
      ])
  ])
  (#any-of? @_storage "static" "thread_local"))

; A `const` object is a constant even at its declaration, so it keeps the accent.
; A pointer *to* const is not: there the qualifier belongs to the pointee, and
; the declarator is a pointer_declarator rather than a bare name.
((declaration
  (type_qualifier) @_qualifier
  declarator: [
    (identifier) @constant
    (init_declarator
      declarator: (identifier) @constant)
  ])
  (#eq? @_qualifier "const"))

; A qualifier is part of the type it qualifies, so it takes the accent with it.
(type_qualifier) @keyword.type

; `__attribute__((unused))` is an annotation; upstream sets its arguments as
; built-in variables, which lands them on the keyword rung.
(attribute_specifier
  (argument_list
    (identifier) @attribute))

(attribute_specifier
  (argument_list
    (call_expression
      function: (identifier) @attribute)))
