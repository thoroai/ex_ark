defmodule ExArk.GenerateTest.Generated do
  @moduledoc false

  # Compiled via `elixirc_paths(:test)` so these modules exist before Jason.Encoder
  # consolidation. Defining `use ExArk.Generate` only inside `test/**/*.exs` runs
  # too late — @derive Jason.Encoder is ignored and Jason.encode/1 fails.

  use ExArk.Generate,
    registry: "test/fixtures/ir/generate.ir",
    namespace: ExArk.GenerateTest.Ns,
    schemas: [
      "ex_ark::gen::test::Primitives",
      "ex_ark::gen::test::WithObject",
      "ex_ark::gen::test::WithOptionals",
      "ex_ark::gen::test::WithGroups",
      "ex_ark::gen::test::WithVariant",
      "ex_ark::gen::test::WithOptionalVariant",
      "ex_ark::gen::test::WithCollections",
      "ex_ark::gen::test::WithEnum"
    ]
end
