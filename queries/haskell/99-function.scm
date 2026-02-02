; Match functions with patterns (arguments) - this excludes signatures
(function
  (patterns)) @context.function

; Match function bodies (the match node containing = and body)
(function
  (patterns)
  (match) @context.body)

; Bindings (like "lambda = \\x -> x + 1") with body
(bind
  (match) @context.body) @context.function

; Lambda expressions
(lambda) @context.function

; Lambda body (everything after ->)
(lambda
  (_) @context.body)
