defmodule ExArk.Types.PrimitivesTest do
  use ExUnit.Case, async: true

  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OutputStream
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

    test "read/1 with float returns pi" do
      {:ok, %Result{reified: 3.1415927410125732}} =
        Primitives.read(:float, %InputStream{bytes: <<219, 15, 73, 64>>, offset: 0})
    end

    test "read/1 with float returns negative pi" do
      {:ok, %Result{reified: -3.1415927410125732}} =
        Primitives.read(:float, %InputStream{bytes: <<219, 15, 73, 192>>, offset: 0})
    end
  end

  describe "serialize floats" do
    test "write/2 float with :positive_infinity sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:float, :positive_infinity, %OutputStream{})
      assert bytes == <<0, 0, 128, 127>>
    end

    test "write/2 float with :negative_infinity sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:float, :negative_infinity, %OutputStream{})
      assert bytes == <<0, 0, 128, 255>>
    end

    test "write/2 float with :nan sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:float, :nan, %OutputStream{})
      assert bytes == <<0, 0, 192, 127>>
    end

    test "write/2 float with floating point value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:float, 1.0, %OutputStream{})
      assert bytes == <<0, 0, 128, 63>>
    end

    test "write/2 float with floating point pi sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:float, 3.1415927410125732, %OutputStream{})
      assert bytes == <<219, 15, 73, 64>>
    end

    test "write/2 float with floating point negative pi sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:float, -3.1415927410125732, %OutputStream{})
      assert bytes == <<219, 15, 73, 192>>
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

    test "read/1 with double returns pi" do
      {:ok, %Result{reified: 3.141592653589793}} =
        Primitives.read(:double, %InputStream{bytes: <<24, 45, 68, 84, 251, 33, 9, 64>>, offset: 0})
    end

    test "read/1 with double returns negative pi" do
      {:ok, %Result{reified: -3.141592653589793}} =
        Primitives.read(:double, %InputStream{bytes: <<24, 45, 68, 84, 251, 33, 9, 192>>, offset: 0})
    end
  end

  describe "serialize doubles" do
    test "write/2 double with :positive_infinity sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:double, :positive_infinity, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 240, 127>>
    end

    test "write/2 double with :negative_infinity sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:double, :negative_infinity, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 240, 255>>
    end

    test "write/2 double with :nan sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:double, :nan, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 248, 127>>
    end

    test "write/2 double with floating point value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:double, 1.0, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 240, 63>>
    end

    test "write/2 double with floating point pi sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:double, 3.141592653589793, %OutputStream{})
      assert bytes == <<24, 45, 68, 84, 251, 33, 9, 64>>
    end

    test "write/2 double with floating point negative pi sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:double, -3.141592653589793, %OutputStream{})
      assert bytes == <<24, 45, 68, 84, 251, 33, 9, 192>>
    end
  end
end
