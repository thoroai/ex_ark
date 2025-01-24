defmodule ExArk.Types.PrimitivesTest do
  use ExUnit.Case, async: true

  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Types.Primitives

  describe "deserialize floats" do
    test "read/1 with float returns :positive_infinity" do
      {:ok, %Result{reified: :positive_infinity}} =
        Primitives.read(:float, %InputStream{bytes: <<0, 0, 128, 127>>, offset: 0})
    end

    test "read/1 with float returns :negative_infinity" do
      {:ok, %Result{reified: :negative_infinity}} =
        Primitives.read(:float, %InputStream{bytes: <<0, 0, 128, 255>>, offset: 0})
    end

    test "read/1 with float returns :nan" do
      {:ok, %Result{reified: :nan}} =
        Primitives.read(:float, %InputStream{bytes: <<0, 0, 192, 127>>, offset: 0})
    end

    test "read/1 with float returns valid float" do
      {:ok, %Result{reified: 1.0}} =
        Primitives.read(:float, %InputStream{bytes: <<0, 0, 128, 63>>, offset: 0})
    end
  end

  describe "deserialize doubles" do
    test "read/1 with double returns :positive_infinity" do
      {:ok, %Result{reified: :positive_infinity}} =
        Primitives.read(:double, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 240, 127>>, offset: 0})
    end

    test "read/1 with double returns :negative_infinity" do
      {:ok, %Result{reified: :negative_infinity}} =
        Primitives.read(:double, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 240, 255>>, offset: 0})
    end

    test "read/1 with double returns :nan" do
      {:ok, %Result{reified: :nan}} =
        Primitives.read(:double, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 248, 127>>, offset: 0})
    end

    test "read/1 with double returns valid double" do
      {:ok, %Result{reified: 1.0}} =
        Primitives.read(:double, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 240, 63>>, offset: 0})
    end
  end
end
