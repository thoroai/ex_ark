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

  describe "deserialize unsigned integers" do
    test "read/2 with uint8 returns zero" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:uint8, %InputStream{bytes: <<0>>, offset: 0})
    end

    test "read/2 with uint8 returns max value" do
      {:ok, %Result{reified: 255}} =
        Primitives.read(:uint8, %InputStream{bytes: <<255>>, offset: 0})
    end

    test "read/2 with uint8 returns nominal value" do
      {:ok, %Result{reified: 42}} =
        Primitives.read(:uint8, %InputStream{bytes: <<42>>, offset: 0})
    end

    test "read/2 with uint16 returns zero" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:uint16, %InputStream{bytes: <<0, 0>>, offset: 0})
    end

    test "read/2 with uint16 returns max value" do
      {:ok, %Result{reified: 65_535}} =
        Primitives.read(:uint16, %InputStream{bytes: <<255, 255>>, offset: 0})
    end

    test "read/2 with uint16 returns nominal value" do
      {:ok, %Result{reified: 12_345}} =
        Primitives.read(:uint16, %InputStream{bytes: <<57, 48>>, offset: 0})
    end

    test "read/2 with uint32 returns zero" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:uint32, %InputStream{bytes: <<0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with uint32 returns max value" do
      {:ok, %Result{reified: 4_294_967_295}} =
        Primitives.read(:uint32, %InputStream{bytes: <<255, 255, 255, 255>>, offset: 0})
    end

    test "read/2 with uint32 returns nominal value" do
      {:ok, %Result{reified: 123_456_789}} =
        Primitives.read(:uint32, %InputStream{bytes: <<21, 205, 91, 7>>, offset: 0})
    end

    test "read/2 with uint64 returns zero" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:uint64, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with uint64 returns max value" do
      {:ok, %Result{reified: 18_446_744_073_709_551_615}} =
        Primitives.read(:uint64, %InputStream{bytes: <<255, 255, 255, 255, 255, 255, 255, 255>>, offset: 0})
    end

    test "read/2 with uint64 returns nominal value" do
      {:ok, %Result{reified: 1_234_567_890_123_456_789}} =
        Primitives.read(:uint64, %InputStream{bytes: <<21, 129, 233, 125, 244, 16, 34, 17>>, offset: 0})
    end
  end

  describe "serialize unsigned integers" do
    test "write/3 uint8 with zero sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint8, 0, %OutputStream{})
      assert bytes == <<0>>
    end

    test "write/3 uint8 with max value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint8, 255, %OutputStream{})
      assert bytes == <<255>>
    end

    test "write/3 uint8 with nominal value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint8, 42, %OutputStream{})
      assert bytes == <<42>>
    end

    test "write/3 uint16 with zero sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint16, 0, %OutputStream{})
      assert bytes == <<0, 0>>
    end

    test "write/3 uint16 with max value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint16, 65_535, %OutputStream{})
      assert bytes == <<255, 255>>
    end

    test "write/3 uint16 with nominal value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint16, 12_345, %OutputStream{})
      assert bytes == <<57, 48>>
    end

    test "write/3 uint32 with zero sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint32, 0, %OutputStream{})
      assert bytes == <<0, 0, 0, 0>>
    end

    test "write/3 uint32 with max value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint32, 4_294_967_295, %OutputStream{})
      assert bytes == <<255, 255, 255, 255>>
    end

    test "write/3 uint32 with nominal value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint32, 123_456_789, %OutputStream{})
      assert bytes == <<21, 205, 91, 7>>
    end

    test "write/3 uint64 with zero sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint64, 0, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 0, 0>>
    end

    test "write/3 uint64 with max value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint64, 18_446_744_073_709_551_615, %OutputStream{})
      assert bytes == <<255, 255, 255, 255, 255, 255, 255, 255>>
    end

    test "write/3 uint64 with nominal value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:uint64, 1_234_567_890_123_456_789, %OutputStream{})
      assert bytes == <<21, 129, 233, 125, 244, 16, 34, 17>>
    end
  end

  describe "deserialize signed integers" do
    test "read/2 with int8 returns zero" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:int8, %InputStream{bytes: <<0>>, offset: 0})
    end

    test "read/2 with int8 returns max positive value" do
      {:ok, %Result{reified: 127}} =
        Primitives.read(:int8, %InputStream{bytes: <<127>>, offset: 0})
    end

    test "read/2 with int8 returns min negative value" do
      {:ok, %Result{reified: -128}} =
        Primitives.read(:int8, %InputStream{bytes: <<128>>, offset: 0})
    end

    test "read/2 with int8 returns nominal positive value" do
      {:ok, %Result{reified: 42}} =
        Primitives.read(:int8, %InputStream{bytes: <<42>>, offset: 0})
    end

    test "read/2 with int8 returns nominal negative value" do
      {:ok, %Result{reified: -42}} =
        Primitives.read(:int8, %InputStream{bytes: <<214>>, offset: 0})
    end

    test "read/2 with int16 returns zero" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:int16, %InputStream{bytes: <<0, 0>>, offset: 0})
    end

    test "read/2 with int16 returns max positive value" do
      {:ok, %Result{reified: 32_767}} =
        Primitives.read(:int16, %InputStream{bytes: <<255, 127>>, offset: 0})
    end

    test "read/2 with int16 returns min negative value" do
      {:ok, %Result{reified: -32_768}} =
        Primitives.read(:int16, %InputStream{bytes: <<0, 128>>, offset: 0})
    end

    test "read/2 with int16 returns nominal positive value" do
      {:ok, %Result{reified: 12_345}} =
        Primitives.read(:int16, %InputStream{bytes: <<57, 48>>, offset: 0})
    end

    test "read/2 with int16 returns nominal negative value" do
      {:ok, %Result{reified: -12_345}} =
        Primitives.read(:int16, %InputStream{bytes: <<199, 207>>, offset: 0})
    end

    test "read/2 with int32 returns zero" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:int32, %InputStream{bytes: <<0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with int32 returns max positive value" do
      {:ok, %Result{reified: 2_147_483_647}} =
        Primitives.read(:int32, %InputStream{bytes: <<255, 255, 255, 127>>, offset: 0})
    end

    test "read/2 with int32 returns min negative value" do
      {:ok, %Result{reified: -2_147_483_648}} =
        Primitives.read(:int32, %InputStream{bytes: <<0, 0, 0, 128>>, offset: 0})
    end

    test "read/2 with int32 returns nominal positive value" do
      {:ok, %Result{reified: 123_456_789}} =
        Primitives.read(:int32, %InputStream{bytes: <<21, 205, 91, 7>>, offset: 0})
    end

    test "read/2 with int32 returns nominal negative value" do
      {:ok, %Result{reified: -123_456_789}} =
        Primitives.read(:int32, %InputStream{bytes: <<235, 50, 164, 248>>, offset: 0})
    end

    test "read/2 with int64 returns zero" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:int64, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with int64 returns max positive value" do
      {:ok, %Result{reified: 9_223_372_036_854_775_807}} =
        Primitives.read(:int64, %InputStream{bytes: <<255, 255, 255, 255, 255, 255, 255, 127>>, offset: 0})
    end

    test "read/2 with int64 returns min negative value" do
      {:ok, %Result{reified: -9_223_372_036_854_775_808}} =
        Primitives.read(:int64, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 0, 128>>, offset: 0})
    end

    test "read/2 with int64 returns nominal positive value" do
      {:ok, %Result{reified: 1_234_567_890_123_456_789}} =
        Primitives.read(:int64, %InputStream{bytes: <<21, 129, 233, 125, 244, 16, 34, 17>>, offset: 0})
    end

    test "read/2 with int64 returns nominal negative value" do
      {:ok, %Result{reified: -1_234_567_890_123_456_789}} =
        Primitives.read(:int64, %InputStream{bytes: <<235, 126, 22, 130, 11, 239, 221, 238>>, offset: 0})
    end
  end

  describe "serialize signed integers" do
    test "write/3 int8 with zero sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int8, 0, %OutputStream{})
      assert bytes == <<0>>
    end

    test "write/3 int8 with max positive value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int8, 127, %OutputStream{})
      assert bytes == <<127>>
    end

    test "write/3 int8 with min negative value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int8, -128, %OutputStream{})
      assert bytes == <<128>>
    end

    test "write/3 int8 with nominal positive value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int8, 42, %OutputStream{})
      assert bytes == <<42>>
    end

    test "write/3 int8 with nominal negative value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int8, -42, %OutputStream{})
      assert bytes == <<214>>
    end

    test "write/3 int16 with zero sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int16, 0, %OutputStream{})
      assert bytes == <<0, 0>>
    end

    test "write/3 int16 with max positive value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int16, 32_767, %OutputStream{})
      assert bytes == <<255, 127>>
    end

    test "write/3 int16 with min negative value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int16, -32_768, %OutputStream{})
      assert bytes == <<0, 128>>
    end

    test "write/3 int16 with nominal positive value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int16, 12_345, %OutputStream{})
      assert bytes == <<57, 48>>
    end

    test "write/3 int16 with nominal negative value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int16, -12_345, %OutputStream{})
      assert bytes == <<199, 207>>
    end

    test "write/3 int32 with zero sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int32, 0, %OutputStream{})
      assert bytes == <<0, 0, 0, 0>>
    end

    test "write/3 int32 with max positive value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int32, 2_147_483_647, %OutputStream{})
      assert bytes == <<255, 255, 255, 127>>
    end

    test "write/3 int32 with min negative value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int32, -2_147_483_648, %OutputStream{})
      assert bytes == <<0, 0, 0, 128>>
    end

    test "write/3 int32 with nominal positive value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int32, 123_456_789, %OutputStream{})
      assert bytes == <<21, 205, 91, 7>>
    end

    test "write/3 int32 with nominal negative value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int32, -123_456_789, %OutputStream{})
      assert bytes == <<235, 50, 164, 248>>
    end

    test "write/3 int64 with zero sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int64, 0, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 0, 0>>
    end

    test "write/3 int64 with max positive value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int64, 9_223_372_036_854_775_807, %OutputStream{})
      assert bytes == <<255, 255, 255, 255, 255, 255, 255, 127>>
    end

    test "write/3 int64 with min negative value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int64, -9_223_372_036_854_775_808, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 0, 128>>
    end

    test "write/3 int64 with nominal positive value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int64, 1_234_567_890_123_456_789, %OutputStream{})
      assert bytes == <<21, 129, 233, 125, 244, 16, 34, 17>>
    end

    test "write/3 int64 with nominal negative value sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:int64, -1_234_567_890_123_456_789, %OutputStream{})
      assert bytes == <<235, 126, 22, 130, 11, 239, 221, 238>>
    end
  end

  describe "deserialize bool" do
    test "read/2 with bool false" do
      {:ok, %Result{reified: false}} =
        Primitives.read(:bool, %InputStream{bytes: <<0>>, offset: 0})
    end

    test "read/2 with bool true (nonzero)" do
      {:ok, %Result{reified: true}} =
        Primitives.read(:bool, %InputStream{bytes: <<1>>, offset: 0})
    end

    test "read/2 with bool true (any nonzero)" do
      {:ok, %Result{reified: true}} =
        Primitives.read(:bool, %InputStream{bytes: <<255>>, offset: 0})
    end
  end

  describe "serialize bool" do
    test "write/3 bool false sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:bool, false, %OutputStream{})
      assert bytes == <<0>>
    end

    test "write/3 bool true sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:bool, true, %OutputStream{})
      assert bytes == <<1>>
    end
  end

  describe "deserialize string" do
    test "read/2 with empty string" do
      {:ok, %Result{reified: ""}} =
        Primitives.read(:string, %InputStream{bytes: <<0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with nominal string" do
      {:ok, %Result{reified: "hello"}} =
        Primitives.read(:string, %InputStream{bytes: <<5, 0, 0, 0, 104, 101, 108, 108, 111>>, offset: 0})
    end
  end

  describe "serialize string" do
    test "write/3 empty string sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:string, "", %OutputStream{})
      assert bytes == <<0, 0, 0, 0>>
    end

    test "write/3 nominal string sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:string, "hello", %OutputStream{})
      assert bytes == <<5, 0, 0, 0, 104, 101, 108, 108, 111>>
    end
  end

  describe "deserialize byte_buffer" do
    test "read/2 with empty byte_buffer" do
      {:ok, %Result{reified: <<>>}} =
        Primitives.read(:byte_buffer, %InputStream{bytes: <<0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with nominal byte_buffer" do
      {:ok, %Result{reified: <<1, 2, 3>>}} =
        Primitives.read(:byte_buffer, %InputStream{bytes: <<3, 0, 0, 0, 1, 2, 3>>, offset: 0})
    end
  end

  describe "serialize byte_buffer" do
    test "write/3 empty byte_buffer sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:byte_buffer, <<>>, %OutputStream{})
      assert bytes == <<0, 0, 0, 0>>
    end

    test "write/3 nominal byte_buffer sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:byte_buffer, <<1, 2, 3>>, %OutputStream{})
      assert bytes == <<3, 0, 0, 0, 1, 2, 3>>
    end
  end

  describe "deserialize guid" do
    test "read/2 with valid guid" do
      # UUID: 00112233-4455-6677-8899-aabbccddeeff
      bin = <<0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88>>

      {:ok, %Result{reified: uuid}} =
        Primitives.read(:guid, %InputStream{bytes: bin, offset: 0})

      assert uuid == "11223344-5566-7700-8899-aabbccddeeff"
    end

    test "read/2 with all-zero guid returns valid uuid" do
      bin = <<0::size(128)>>

      {:ok, %Result{reified: uuid}} =
        Primitives.read(:guid, %InputStream{bytes: bin, offset: 0})

      assert uuid == "00000000-0000-0000-0000-000000000000"
    end
  end

  describe "serialize guid" do
    test "write/3 valid guid sets proper bytes" do
      uuid = "00112233-4455-6677-8899-aabbccddeeff"
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:guid, uuid, %OutputStream{})
      assert bytes == <<0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88>>
    end
  end

  describe "deserialize duration" do
    test "read/2 with zero duration" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:duration, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with positive duration" do
      {:ok, %Result{reified: 123_456_789}} =
        Primitives.read(:duration, %InputStream{bytes: <<21, 205, 91, 7, 0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with negative duration" do
      {:ok, %Result{reified: -123_456_789}} =
        Primitives.read(:duration, %InputStream{bytes: <<235, 50, 164, 248, 255, 255, 255, 255>>, offset: 0})
    end
  end

  describe "serialize duration" do
    test "write/3 zero duration sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:duration, 0, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 0, 0>>
    end

    test "write/3 positive duration sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:duration, 123_456_789, %OutputStream{})
      assert bytes == <<21, 205, 91, 7, 0, 0, 0, 0>>
    end

    test "write/3 negative duration sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:duration, -123_456_789, %OutputStream{})
      assert bytes == <<235, 50, 164, 248, 255, 255, 255, 255>>
    end
  end

  describe "deserialize steady_time_point" do
    test "read/2 with zero steady_time_point" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:steady_time_point, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with nominal steady_time_point" do
      {:ok, %Result{reified: 1_234_567_890_123_456_789}} =
        Primitives.read(:steady_time_point, %InputStream{bytes: <<21, 129, 233, 125, 244, 16, 34, 17>>, offset: 0})
    end
  end

  describe "serialize steady_time_point" do
    test "write/3 zero steady_time_point sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:steady_time_point, 0, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 0, 0>>
    end

    test "write/3 nominal steady_time_point sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} =
        Primitives.write(:steady_time_point, 1_234_567_890_123_456_789, %OutputStream{})

      assert bytes == <<21, 129, 233, 125, 244, 16, 34, 17>>
    end
  end

  describe "deserialize system_time_point" do
    test "read/2 with zero system_time_point" do
      {:ok, %Result{reified: 0}} =
        Primitives.read(:system_time_point, %InputStream{bytes: <<0, 0, 0, 0, 0, 0, 0, 0>>, offset: 0})
    end

    test "read/2 with nominal system_time_point" do
      {:ok, %Result{reified: 9_876_543_210_987_654_321}} =
        Primitives.read(:system_time_point, %InputStream{bytes: <<177, 12, 183, 227, 184, 135, 16, 137>>, offset: 0})
    end
  end

  describe "serialize system_time_point" do
    test "write/3 zero system_time_point sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} = Primitives.write(:system_time_point, 0, %OutputStream{})
      assert bytes == <<0, 0, 0, 0, 0, 0, 0, 0>>
    end

    test "write/3 nominal system_time_point sets proper bytes" do
      {:ok, %OutputStream{bytes: bytes}} =
        Primitives.write(:system_time_point, 9_876_543_210_987_654_321, %OutputStream{})

      assert bytes == <<177, 12, 183, 227, 184, 135, 16, 137>>
    end
  end
end
