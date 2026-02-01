; Top-level function declarations
(function) @context.function

; Function equations with body
(function
  (equations
    (equation
      rhs: (_) @context.body)))

; Lambda expressions
(exp_lambda
  body: (_) @context.body) @context.function

; Pattern bindings (for simple definitions)
(pattern_binding) @context.function

; Pattern binding with body
(pattern_binding
  rhs: (_) @context.body)
