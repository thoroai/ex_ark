defmodule ExArk.Generate.DialyzerSample do
  @moduledoc false

  # This module gives dialyzer a concrete generated module to analyze, so that
  # mix dialyzer run inside the ex_ark project will surface any invalid_contract
  # warnings from ExArk.Generate the same way they appear in consumer projects.
  #
  # Schemas chosen to cover the field types most likely to trigger dialyzer
  # issues: object fields (WithObject) and variant fields (WithVariant).

  use ExArk.Generate,
    registry: Path.expand("../fixtures/ir/generate.ir", __DIR__),
    namespace: ExArk.Generate.Sample,
    schemas: [
      "ex_ark::gen::test::WithObject",
      "ex_ark::gen::test::WithVariant",
      "ex_ark::gen::test::Primitives"
    ]
end
