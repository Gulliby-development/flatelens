local BitReader = require("flatelens.bits.bitreader")
local Huffman = require("flatelens.bits.huffman")
local Problem = require("flatelens.model.problem")

local function from_hex(text)
  local compact = text:gsub("%s", "")
  return (compact:gsub("%x%x", function(pair)
    return string.char(tonumber(pair, 16))
  end))
end

local function as_binary(code, width)
  local bits = {}
  for shift = width - 1, 0, -1 do
    bits[#bits + 1] = tostring((code >> shift) & 1)
  end
  return table.concat(bits)
end

describe("Huffman", function()
  it("builds canonical codes and reports literal occupancy metadata", function()
    local cases = {
      {
        lengths = { 3, 3, 3, 3, 3, 2, 4, 4 },
        codes = { 2, 3, 4, 5, 6, 0, 14, 15 },
        used = 8,
        max = 4,
        status = "complete",
        numerator = 16,
        denominator = 16,
        binary = "010,011,100,101,110,00,1110,1111",
      },
      {
        lengths = { 2, 1, 3 },
        codes = { 2, 0, 6 },
        used = 3,
        max = 3,
        status = "incomplete",
        numerator = 7,
        denominator = 8,
      },
      {
        lengths = { 1, 1, 1 },
        codes = {},
        used = 3,
        max = 1,
        status = "over-subscribed",
        numerator = 3,
        denominator = 2,
      },
      {
        lengths = { 1, 1 },
        codes = { 0, 1 },
        used = 2,
        max = 1,
        status = "complete",
        numerator = 2,
        denominator = 2,
      },
      {
        lengths = { 1 },
        codes = { 0 },
        used = 1,
        max = 1,
        status = "incomplete",
        numerator = 1,
        denominator = 2,
      },
      {
        lengths = { 0, 0 },
        codes = {},
        used = 0,
        max = 0,
        status = "empty",
        numerator = 0,
        denominator = 1,
      },
      {
        lengths = { 3, 2, 2, 0, 3 },
        codes = { [1] = 4, [2] = 0, [3] = 1, [5] = 5 },
        used = 4,
        max = 3,
        status = "incomplete",
        numerator = 6,
        denominator = 8,
        code_sequence = "4,0,1,nil,5",
      },
    }

    for _, case in ipairs(cases) do
      local huffman = Huffman.build(case.lengths)
      assert.are.equal(case.used, huffman.used)
      assert.are.equal(case.max, huffman.max)
      assert.are.equal(case.status, huffman.status)
      assert.are.equal(case.numerator, huffman.numerator)
      assert.are.equal(case.denominator, huffman.denominator)
      assert.are.equal("integer", math.type(huffman.numerator))
      assert.are.equal("integer", math.type(huffman.denominator))

      local actual_codes = {}
      for index = 1, #case.lengths do
        assert.are.equal(case.codes[index], huffman.codes[index])
        actual_codes[index] = tostring(huffman.codes[index])
      end
      if case.binary then
        local actual_binary = {}
        for index = 1, #case.lengths do
          actual_binary[index] = as_binary(huffman.codes[index], case.lengths[index])
        end
        assert.are.equal(case.binary, table.concat(actual_binary, ","))
      end
      if case.code_sequence then
        assert.are.equal(case.code_sequence, table.concat(actual_codes, ","))
      end
    end
  end)

  it([[build({2,1,3}); new("0d"); decode three times]], function()
    local huffman = Huffman.build({ 2, 1, 3 })
    local reader = BitReader.new(from_hex("0d"))

    local symbol, start_pos = huffman:decode(reader)
    assert.are.equal(0, symbol)
    assert.are.equal(0, start_pos)
    assert.are.equal(2, reader:position())

    symbol, start_pos = huffman:decode(reader)
    assert.are.equal(2, symbol)
    assert.are.equal(2, start_pos)
    assert.are.equal(5, reader:position())

    symbol, start_pos = huffman:decode(reader)
    assert.are.equal(1, symbol)
    assert.are.equal(5, start_pos)
    assert.are.equal(6, reader:position())

    local unaligned = BitReader.new(from_hex("28"), 3)
    symbol, start_pos = huffman:decode(unaligned)
    assert.are.equal(0, symbol)
    assert.are.equal(3, start_pos)
    assert.are.equal(5, unaligned:position())

    local maximum_length = Huffman.build({ 15 })
    local full_code = BitReader.new(from_hex("00 00"))
    symbol, start_pos = maximum_length:decode(full_code)
    assert.are.equal(0, symbol)
    assert.are.equal(0, start_pos)
    assert.are.equal(15, full_code:position())
  end)

  it("stops unmatched codes after 15 bits, including for an empty code", function()
    local cases = {
      { lengths = { 1 }, data = "ff ff" },
      { lengths = { 0, 0 }, data = "ff ff" },
    }

    for _, case in ipairs(cases) do
      local reader = BitReader.new(from_hex(case.data))
      local symbol, start_pos = Huffman.build(case.lengths):decode(reader)
      assert.is_nil(symbol)
      assert.are.equal("(nil,0)", string.format("(%s,%d)", tostring(symbol), start_pos))
      assert.are.equal(0, start_pos)
      assert.are.equal(15, reader:position())
    end
  end)

  it("propagates FL001 when decoding a code is truncated", function()
    local reader = BitReader.new(from_hex("00"))
    local huffman = Huffman.build({ 15 })
    local ok, problem = pcall(function()
      huffman:decode(reader)
    end)

    assert.is_false(ok)
    assert.is_true(Problem.is(problem))
    assert.are.equal("FL001", problem.code)
    assert.are.equal("unexpected end of data", problem.text)
    assert.are.equal(8, problem.pos)
  end)
end)
