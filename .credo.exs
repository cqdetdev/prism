%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "bench/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: [
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Design.AliasUsage, false},
        {Credo.Check.Readability.AliasOrder, false},
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, false},
        {Credo.Check.Readability.PredicateFunctionNames, false},
        {Credo.Check.Readability.WithSingleClause, false},
        {Credo.Check.Refactor.CyclomaticComplexity, false},
        {Credo.Check.Refactor.Nesting, false}
      ]
    }
  ]
}
