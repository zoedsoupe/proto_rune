# Used by "mix format"
[
  import_deps: [:peri],
  plugins: [Styler],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [
    locals_without_parens: [
      defquery: 2,
      defquery: 3,
      defprocedure: 3,
      defprocedure: 2,
      param: 2
    ]
  ],
  locals_without_parens: [
    defquery: 2,
    defquery: 3,
    defprocedure: 3,
    defprocedure: 2,
    param: 2
  ]
]
