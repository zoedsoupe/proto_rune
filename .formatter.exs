# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [
    locals_without_parens: [
      defquery: 1,
      defquery: 2,
      defprocedure: 3,
      param: 2
    ]
  ]
]
