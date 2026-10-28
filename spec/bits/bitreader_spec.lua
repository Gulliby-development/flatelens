local BitReader = require("flatelens.bits.bitreader")
local Problem = require("flatelens.model.problem")

local function from_hex(text)
  local compact = text:gsub("%s", "")
  return (compact:gsub("%x%x", function(pair)
    return string.char(tonumber(pair, 16))
  end))
end

describe("BitReader", function()
  it("reads LSB-first fields and keeps absolute bit positions", function()
    local reader = BitReader.new(from_hex("b2 61"))
    assert.are.equal(2, reader:read(3))
    assert.are.equal(3, reader:position())
    assert.are.equal(54, reader:read(7))
    assert.are.equal(10, reader:position())
    assert.are.equal(24, reader:read(6))
    assert.are.equal(16, reader:position())

    local absolute = BitReader.new(from_hex("ff 01"), 9)
    assert.are.equal(0, absolute:read(1))
    assert.are.equal(10, absolute:position())

    local unaligned = BitReader.new(from_hex("ff 01"), 3)
    unaligned:align()
    assert.are.equal(8, unaligned:position())
    assert.are.equal(1, unaligned:read(8))
    assert.are.equal(16, unaligned:position())

    local aligned = BitReader.new(from_hex("ff"))
    aligned:align()
    assert.are.equal(0, aligned:position())
    assert.are.equal(0, aligned:read(0))
    assert.are.equal(0, aligned:position())

    local wide = BitReader.new(from_hex("78 56 34 12"))
    assert.are.equal(305419896, wide:read(32))
    assert.are.equal(32, wide:position())
  end)

  it("raises FL001 at the absolute end position when a read is exhausted", function()
    local cases = {
      { data = "", start_bit = 0, count = 1, pos = 0 },
      { data = "ff", start_bit = 0, count = 9, pos = 8 },
      { data = "ff 00", start_bit = 16, count = 1, pos = 16 },
    }

    for _, case in ipairs(cases) do
      local reader = BitReader.new(from_hex(case.data), case.start_bit)
      local ok, problem = pcall(function()
        reader:read(case.count)
      end)
      assert.is_false(ok)
      assert.is_true(Problem.is(problem))
      assert.are.equal("FL001", problem.code)
      assert.are.equal("unexpected end of data", problem.text)
      assert.are.equal(case.pos, problem.pos)
    end
  end)
end)
