defmodule ExArk.Serdes.Json.Fields.PrimitivesTest do
  use ExUnit.Case, async: true

  alias ExArk.Serdes.Json.Fields.Primitives
  alias ExArk.Serdes.Json.Reader
  alias ExArk.Serdes.Json.Reader.Result, as: ReaderResult
  alias ExArk.Serdes.Json.Writer.Result, as: WriterResult

  describe "deserialize floats" do
    test "read/1 with float returns :positive_infinity" do
      {:ok, %ReaderResult{reified: :positive_infinity}} =
        Primitives.read(:float, %Reader{decoded: Primitives.inf()})
    end

    test "read/1 with float returns :negative_infinity" do
      {:ok, %ReaderResult{reified: :negative_infinity}} =
        Primitives.read(:float, %Reader{decoded: -Primitives.inf()})
    end

    test "read/1 with float returns :nan" do
      {:ok, %ReaderResult{reified: :nan}} =
        Primitives.read(:float, %Reader{decoded: nil})
    end

    test "read/1 with float returns valid float" do
      {:ok, %ReaderResult{reified: 1.0}} =
        Primitives.read(:float, %Reader{decoded: 1.0})
    end

    test "read/1 with float returns pi" do
      {:ok, %ReaderResult{reified: 3.1415927410125732}} =
        Primitives.read(:float, %Reader{decoded: 3.1415927410125732})
    end

    test "read/1 with float returns negative pi" do
      {:ok, %ReaderResult{reified: -3.1415927410125732}} =
        Primitives.read(:float, %Reader{decoded: -3.1415927410125732})
    end
  end

  describe "serialize floats" do
    test "write/3 float with :positive_infinity sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:float, :positive_infinity)
      assert encoded == Primitives.float_inf()
    end

    test "write/3 float with :negative_infinity sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:float, :negative_infinity)
      assert encoded == -Primitives.float_inf()
    end

    test "write/3 float with :nan sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:float, :nan)
      assert encoded == nil
    end

    test "write/3 float with floating point value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:float, 1.0)
      assert encoded == 1.0
    end

    @tag :skip
    test "write/3 float with floating point pi sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:float, 3.1415927410125732)
      assert encoded == 3.1415927410125732
    end

    @tag :skip
    test "write/3 float with floating point negative pi sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:float, -3.1415927410125732)
      assert encoded == -3.1415927410125732
    end
  end

  describe "deserialize doubles" do
    test "read/1 with double returns :positive_infinity" do
      {:ok, %ReaderResult{reified: :positive_infinity}} =
        Primitives.read(:double, %Reader{decoded: Primitives.double_inf()})
    end

    test "read/1 with double returns :negative_infinity" do
      {:ok, %ReaderResult{reified: :negative_infinity}} =
        Primitives.read(:double, %Reader{decoded: -Primitives.double_inf()})
    end

    test "read/1 with double returns :nan" do
      {:ok, %ReaderResult{reified: :nan}} = Primitives.read(:double, %Reader{decoded: nil})
    end

    test "read/1 with double returns valid double" do
      {:ok, %ReaderResult{reified: 1.0}} = Primitives.read(:double, %Reader{decoded: 1.0})
    end

    @tag :skip
    test "read/1 with double returns pi" do
      {:ok, %ReaderResult{reified: 3.141592653589793}} =
        Primitives.read(:double, %Reader{decoded: 3.141592653589793})
    end

    @tag :skip
    test "read/1 with double returns negative pi" do
      {:ok, %ReaderResult{reified: -3.141592653589793}} =
        Primitives.read(:double, %Reader{decoded: -3.141592653589793})
    end
  end

  describe "serialize doubles" do
    test "write/3 double with :positive_infinity sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:double, :positive_infinity)
      assert encoded == Primitives.double_inf()
    end

    test "write/3 double with :negative_infinity sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:double, :negative_infinity)
      assert encoded == -Primitives.double_inf()
    end

    test "write/3 double with :nan sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:double, :nan)
      assert encoded == nil
    end

    test "write/3 double with doubleing point value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:double, 1.0)
      assert encoded == 1.0
    end

    @tag :skip
    test "write/3 double with doubleing point pi sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:double, 3.141592653589793)
      assert encoded == 3.141592653589793
    end

    @tag :skip
    test "write/3 double with doubleing point negative pi sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:double, -3.141592653589793)
      assert encoded == -3.141592653589793
    end
  end

  describe "deserialize unsigned integers" do
    @describetag :skip

    test "read/2 with uint8 returns zero" do
      {:ok, %ReaderResult{reified: 0}} = Primitives.read(:uint8, %Reader{decoded: 0})
    end

    test "read/2 with uint8 returns max value" do
      {:ok, %ReaderResult{reified: 255}} = Primitives.read(:uint8, %Reader{decoded: 255})
    end

    test "read/2 with uint8 returns nominal value" do
      {:ok, %ReaderResult{reified: 42}} = Primitives.read(:uint8, %Reader{decoded: 42})
    end

    test "read/2 with uint16 returns zero" do
      {:ok, %ReaderResult{reified: 0}} = Primitives.read(:uint16, %Reader{decoded: 0})
    end

    test "read/2 with uint16 returns max value" do
      {:ok, %ReaderResult{reified: 65_535}} = Primitives.read(:uint16, %Reader{decoded: 65_535})
    end

    test "read/2 with uint16 returns nominal value" do
      {:ok, %ReaderResult{reified: 12_345}} = Primitives.read(:uint16, %Reader{decoded: 12_345})
    end

    test "read/2 with uint32 returns zero" do
      {:ok, %ReaderResult{reified: 0}} = Primitives.read(:uint32, %Reader{decoded: 0})
    end

    test "read/2 with uint32 returns max value" do
      {:ok, %ReaderResult{reified: 4_294_967_295}} = Primitives.read(:uint32, %Reader{decoded: 4_294_967_295})
    end

    test "read/2 with uint32 returns nominal value" do
      {:ok, %ReaderResult{reified: 123_456_789}} = Primitives.read(:uint32, %Reader{decoded: 123_456_789})
    end

    test "read/2 with uint64 returns zero" do
      {:ok, %ReaderResult{reified: 0}} = Primitives.read(:uint64, %Reader{decoded: 0})
    end

    test "read/2 with uint64 returns max value" do
      {:ok, %ReaderResult{reified: 18_446_744_073_709_551_615}} =
        Primitives.read(:uint64, %Reader{decoded: 18_446_744_073_709_551_615})
    end

    test "read/2 with uint64 returns nominal value" do
      {:ok, %ReaderResult{reified: 1_234_567_890_123_456_789}} =
        Primitives.read(:uint64, %Reader{decoded: 1_234_567_890_123_456_789})
    end
  end

  describe "serialize unsigned integers" do
    @describetag :skip

    test "write/3 uint8 with zero sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint8, 0)
      assert encoded == 0
    end

    test "write/3 uint8 with max value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint8, 255)
      assert encoded == 255
    end

    test "write/3 uint8 with nominal value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint8, 42)
      assert encoded == 42
    end

    test "write/3 uint16 with zero sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint16, 0)
      assert encoded == 0
    end

    test "write/3 uint16 with max value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint16, 65_535)
      assert encoded == 65_535
    end

    test "write/3 uint16 with nominal value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint16, 12_345)
      assert encoded == 12_345
    end

    test "write/3 uint32 with zero sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint32, 0)
      assert encoded == 0
    end

    test "write/3 uint32 with max value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint32, 4_294_967_295)
      assert encoded == 4_294_967_295
    end

    test "write/3 uint32 with nominal value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint32, 123_456_789)
      assert encoded == 123_456_789
    end

    test "write/3 uint64 with zero sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint64, 0)
      assert encoded == 0
    end

    test "write/3 uint64 with max value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint64, 18_446_744_073_709_551_615)
      assert encoded == 18_446_744_073_709_551_615
    end

    test "write/3 uint64 with nominal value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:uint64, 1_234_567_890_123_456_789)
      assert encoded == 1_234_567_890_123_456_789
    end
  end

  describe "deserialize signed integers" do
    @describetag :skip

    test "read/2 with int8 returns zero" do
      {:ok, %ReaderResult{reified: 0}} = Primitives.read(:int8, %Reader{decoded: 0})
    end

    test "read/2 with int8 returns max positive value" do
      {:ok, %ReaderResult{reified: 127}} = Primitives.read(:int8, %Reader{decoded: 127})
    end

    test "read/2 with int8 returns min negative value" do
      {:ok, %ReaderResult{reified: -128}} = Primitives.read(:int8, %Reader{decoded: -128})
    end

    test "read/2 with int8 returns nominal positive value" do
      {:ok, %ReaderResult{reified: 42}} = Primitives.read(:int8, %Reader{decoded: 42})
    end

    test "read/2 with int8 returns nominal negative value" do
      {:ok, %ReaderResult{reified: -42}} = Primitives.read(:int8, %Reader{decoded: -42})
    end

    test "read/2 with int16 returns zero" do
      {:ok, %ReaderResult{reified: 0}} = Primitives.read(:int16, %Reader{decoded: 0})
    end

    test "read/2 with int16 returns max positive value" do
      {:ok, %ReaderResult{reified: 32_767}} = Primitives.read(:int16, %Reader{decoded: 32_767})
    end

    test "read/2 with int16 returns min negative value" do
      {:ok, %ReaderResult{reified: -32_768}} = Primitives.read(:int16, %Reader{decoded: -32_768})
    end

    test "read/2 with int16 returns nominal positive value" do
      {:ok, %ReaderResult{reified: 12_345}} = Primitives.read(:int16, %Reader{decoded: 12_345})
    end

    test "read/2 with int16 returns nominal negative value" do
      {:ok, %ReaderResult{reified: -12_345}} = Primitives.read(:int16, %Reader{decoded: -12_345})
    end

    test "read/2 with int32 returns zero" do
      {:ok, %ReaderResult{reified: 0}} = Primitives.read(:int32, %Reader{decoded: 0})
    end

    test "read/2 with int32 returns max positive value" do
      {:ok, %ReaderResult{reified: 2_147_483_647}} = Primitives.read(:int32, %Reader{decoded: 2_147_483_647})
    end

    test "read/2 with int32 returns min negative value" do
      {:ok, %ReaderResult{reified: -2_147_483_648}} = Primitives.read(:int32, %Reader{decoded: -2_147_483_648})
    end

    test "read/2 with int32 returns nominal positive value" do
      {:ok, %ReaderResult{reified: 123_456_789}} = Primitives.read(:int32, %Reader{decoded: 123_456_789})
    end

    test "read/2 with int32 returns nominal negative value" do
      {:ok, %ReaderResult{reified: -123_456_789}} = Primitives.read(:int32, %Reader{decoded: -123_456_789})
    end

    test "read/2 with int64 returns zero" do
      {:ok, %ReaderResult{reified: 0}} = Primitives.read(:int64, %Reader{decoded: 0})
    end

    test "read/2 with int64 returns max positive value" do
      {:ok, %ReaderResult{reified: 9_223_372_036_854_775_807}} =
        Primitives.read(:int64, %Reader{decoded: 9_223_372_036_854_775_807})
    end

    test "read/2 with int64 returns min negative value" do
      {:ok, %ReaderResult{reified: -9_223_372_036_854_775_808}} =
        Primitives.read(:int64, %Reader{decoded: -9_223_372_036_854_775_808})
    end

    test "read/2 with int64 returns nominal positive value" do
      {:ok, %ReaderResult{reified: 1_234_567_890_123_456_789}} =
        Primitives.read(:int64, %Reader{decoded: 1_234_567_890_123_456_789})
    end

    test "read/2 with int64 returns nominal negative value" do
      {:ok, %ReaderResult{reified: -1_234_567_890_123_456_789}} =
        Primitives.read(:int64, %Reader{decoded: -1_234_567_890_123_456_789})
    end
  end

  describe "serialize signed integers" do
    @describetag :skip

    test "write/3 int8 with zero sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int8, 0)
      assert encoded == 0
    end

    test "write/3 int8 with max positive value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int8, 127)
      assert encoded == 127
    end

    test "write/3 int8 with min negative value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int8, -128)
      assert encoded == -128
    end

    test "write/3 int8 with nominal positive value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int8, 42)
      assert encoded == 42
    end

    test "write/3 int8 with nominal negative value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int8, -42)
      assert encoded == -42
    end

    test "write/3 int16 with zero sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int16, 0)
      assert encoded == 0
    end

    test "write/3 int16 with max positive value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int16, 32_767)
      assert encoded == 32_767
    end

    test "write/3 int16 with min negative value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int16, -32_768)
      assert encoded == -32_768
    end

    test "write/3 int16 with nominal positive value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int16, 12_345)
      assert encoded == 12_345
    end

    test "write/3 int16 with nominal negative value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int16, -12_345)
      assert encoded == -12_345
    end

    test "write/3 int32 with zero sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int32, 0)
      assert encoded == 0
    end

    test "write/3 int32 with max positive value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int32, 2_147_483_647)
      assert encoded == 2_147_483_647
    end

    test "write/3 int32 with min negative value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int32, -2_147_483_648)
      assert encoded == -2_147_483_648
    end

    test "write/3 int32 with nominal positive value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int32, 123_456_789)
      assert encoded == 123_456_789
    end

    test "write/3 int32 with nominal negative value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int32, -123_456_789)
      assert encoded == -123_456_789
    end

    test "write/3 int64 with zero sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int64, 0)
      assert encoded == 0
    end

    test "write/3 int64 with max positive value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int64, 9_223_372_036_854_775_807)
      assert encoded == 9_223_372_036_854_775_807
    end

    test "write/3 int64 with min negative value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int64, -9_223_372_036_854_775_808)
      assert encoded == -9_223_372_036_854_775_808
    end

    test "write/3 int64 with nominal positive value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int64, 1_234_567_890_123_456_789)
      assert encoded == 1_234_567_890_123_456_789
    end

    test "write/3 int64 with nominal negative value sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:int64, -1_234_567_890_123_456_789)
      assert encoded == -1_234_567_890_123_456_789
    end
  end

  describe "deserialize bool" do
    @describetag :skip

    test "read/2 with bool false" do
      {:ok, %ReaderResult{reified: false}} = Primitives.read(:bool, %Reader{decoded: false})
    end

    test "read/2 with bool true (nonzero)" do
      {:ok, %ReaderResult{reified: true}} = Primitives.read(:bool, %Reader{decoded: true})
    end
  end

  describe "serialize bool" do
    @describetag :skip

    test "write/3 bool false sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:bool, false)
      assert encoded == false
    end

    test "write/3 bool true sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:bool, true)
      assert encoded == true
    end
  end

  describe "deserialize string" do
    @describetag :skip

    test "read/2 with empty string" do
      {:ok, %ReaderResult{reified: ""}} = Primitives.read(:string, %Reader{decoded: ""})
    end

    test "read/2 with nominal string" do
      {:ok, %ReaderResult{reified: "hello"}} = Primitives.read(:string, %Reader{decoded: "hello"})
    end
  end

  describe "serialize string" do
    @describetag :skip

    test "write/3 empty string sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:string, "")
      assert encoded == ""
    end

    test "write/3 nominal string sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:string, "hello")
      assert encoded == "hello"
    end
  end

  describe "deserialize byte_buffer" do
    test "read/2 with empty byte_buffer" do
      {:ok, %ReaderResult{reified: <<>>}} =
        Primitives.read(:byte_buffer, %Reader{decoded: []})
    end

    test "read/2 with nominal byte_buffer" do
      {:ok, %ReaderResult{reified: <<1, 2, 3>>}} =
        Primitives.read(:byte_buffer, %Reader{decoded: [1, 2, 3]})
    end
  end

  describe "serialize byte_buffer" do
    test "write/3 empty byte_buffer sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:byte_buffer, <<>>)
      assert encoded == []
    end

    test "write/3 nominal byte_buffer sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:byte_buffer, <<1, 2, 3>>)
      assert encoded == [1, 2, 3]
    end
  end

  describe "deserialize guid" do
    @describetag :skip

    test "read/2 with valid guid" do
      {:ok, %ReaderResult{reified: uuid}} =
        Primitives.read(:guid, %Reader{decoded: "00112233-4455-6677-8899-aabbccddeeff"})

      assert uuid == "00112233-4455-6677-8899-aabbccddeeff"
    end

    test "read/2 with all-zero guid returns valid uuid" do
      {:ok, %ReaderResult{reified: uuid}} =
        Primitives.read(:guid, %Reader{decoded: "00000000-0000-0000-0000-000000000000"})

      assert uuid == "00000000-0000-0000-0000-000000000000"
    end
  end

  describe "serialize guid" do
    @describetag :skip

    test "write/3 valid guid sets proper bytes" do
      uuid = "00112233-4455-6677-8899-aabbccddeeff"
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:guid, uuid)
      assert encoded == "00112233-4455-6677-8899-aabbccddeeff"
    end
  end

  describe "deserialize duration" do
    @describetag :skip

    test "read/2 with zero duration" do
      {:ok, %ReaderResult{reified: 0}} =
        Primitives.read(:duration, %Reader{decoded: 0})
    end

    test "read/2 with positive duration" do
      {:ok, %ReaderResult{reified: 123_456_789}} =
        Primitives.read(:duration, %Reader{decoded: 123_456_789})
    end

    test "read/2 with negative duration" do
      {:ok, %ReaderResult{reified: -123_456_789}} =
        Primitives.read(:duration, %Reader{decoded: -123_456_789})
    end
  end

  describe "serialize duration" do
    @describetag :skip

    test "write/3 zero duration sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:duration, 0)
      assert encoded == 0
    end

    test "write/3 positive duration sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:duration, 123_456_789)
      assert encoded == 123_456_789
    end

    test "write/3 negative duration sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:duration, -123_456_789)
      assert encoded == -123_456_789
    end
  end

  describe "deserialize steady_time_point" do
    @describetag :skip

    test "read/2 with zero steady_time_point" do
      {:ok, %ReaderResult{reified: 0}} =
        Primitives.read(:steady_time_point, %Reader{decoded: 0})
    end

    test "read/2 with nominal steady_time_point" do
      {:ok, %ReaderResult{reified: 1_234_567_890_123_456_789}} =
        Primitives.read(:steady_time_point, %Reader{decoded: 1_234_567_890_123_456_789})
    end
  end

  describe "serialize steady_time_point" do
    @describetag :skip

    test "write/3 zero steady_time_point sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:steady_time_point, 0)
      assert encoded == 0
    end

    test "write/3 nominal steady_time_point sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} =
        Primitives.write(:steady_time_point, 1_234_567_890_123_456_789)

      assert encoded == 1_234_567_890_123_456_789
    end
  end

  describe "deserialize system_time_point" do
    @describetag :skip

    test "read/2 with zero system_time_point" do
      {:ok, %ReaderResult{reified: 0}} =
        Primitives.read(:system_time_point, %Reader{decoded: 0})
    end

    test "read/2 with nominal system_time_point" do
      {:ok, %ReaderResult{reified: 9_876_543_210_987_654_321}} =
        Primitives.read(:system_time_point, %Reader{decoded: 9_876_543_210_987_654_321})
    end
  end

  describe "serialize system_time_point" do
    @describetag :skip

    test "write/3 zero system_time_point sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} = Primitives.write(:system_time_point, 0)
      assert encoded == 0
    end

    test "write/3 nominal system_time_point sets proper bytes" do
      {:ok, %WriterResult{encoded: encoded}} =
        Primitives.write(:system_time_point, 9_876_543_210_987_654_321)

      assert encoded == 9_876_543_210_987_654_321
    end
  end
end
