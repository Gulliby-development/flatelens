local BitReader = require("flatelens.bits.bitreader")
local DynamicHeader = require("flatelens.inflate.header")
local Problem = require("flatelens.model.problem")

local function bytes(hex)
  return (
    hex:gsub("%s", ""):gsub("%x%x", function(pair)
      return string.char(tonumber(pair, 16))
    end)
  )
end

local function read_header(hex, block_start, start_bit)
  local reader = BitReader.new(bytes(hex), start_bit or 3)
  return DynamicHeader.read(reader, block_start or 0)
end

local function nonzero_lengths(lengths)
  local result = {}
  for symbol = 0, #lengths - 1 do
    if lengths[symbol + 1] ~= 0 then
      result[symbol] = lengths[symbol + 1]
    end
  end
  return result
end

local function assert_problem(hex, code, text, pos, block_start, start_bit)
  local ok, value = pcall(function()
    return read_header(hex, block_start, start_bit)
  end)

  assert.is_false(ok)
  assert.is_true(Problem.is(value))
  assert.are.equal(code, value.code)
  assert.are.equal(text, value.text)
  assert.are.equal(pos, value.pos)
end

describe("flatelens.inflate.header", function()
  it("reports each supplied malformed dynamic-header fixture exactly", function()
    local cases = {
      {
        "f5 00 00 00",
        "FL012",
        "too many length or distance symbols: HLIT 287, HDIST 1",
      },
      { "05 00 92 00", "FL013", "code length code is over-subscribed" },
      { "05 00 02 24", "FL014", "invalid code length repeat" },
      {
        "05 c0 01 04 " .. string.rep("00 ", 4) .. "10 " .. string.rep("00 ", 33),
        "FL015",
        "no end-of-block code (symbol 256 has length 0)",
      },
      {
        "05 c0 01 04 " .. string.rep("00 ", 4) .. "90 03 " .. string.rep("00 ", 30) .. "80 00",
        "FL016",
        "literal/length code is over-subscribed",
      },
      {
        "05 80 01 04 00 00 00 40 " .. string.rep("00 ", 32) .. "02",
        "FL016",
        "literal/length code is incomplete",
      },
      {
        "05 c2 01 04 " .. string.rep("00 ", 4) .. "90 " .. string.rep("00 ", 31) .. "80 07",
        "FL017",
        "distance code is over-subscribed",
      },
    }

    for _, case in ipairs(cases) do
      assert_problem(case[1], case[2], case[3], 0)
    end
  end)

  it("reads every count before validating symbol limits and reports absolute starts", function()
    assert_problem("f5 00", "FL001", "unexpected end of data", 16)
    assert_problem(
      "05 1e 00",
      "FL012",
      "too many length or distance symbols: HLIT 257, HDIST 31",
      0
    )
    assert_problem(
      "05 1f 00",
      "FL012",
      "too many length or distance symbols: HLIT 257, HDIST 32",
      0
    )
    assert_problem(
      "00 f5 00 00 00",
      "FL012",
      "too many length or distance symbols: HLIT 287, HDIST 1",
      8,
      8,
      11
    )
  end)

  it("treats empty and incomplete code-length trees as incomplete", function()
    assert_problem("05 00 00 00", "FL013", "code length code is incomplete", 0)
    assert_problem("05 00 02 00", "FL013", "code length code is incomplete", 0)
  end)

  it("rejects overlong repeats for symbols 16, 17 and 18", function()
    local cases = {
      { "05 c0 d9 0e 00 00 00 40 a0 ff ff eb 03", "FL014" },
      { "05 c0 d9 0e 00 00 00 40 a0 ff 7f ff e1 07", "FL014" },
      { "05 c0 d9 0e 00 00 00 40 a0 ff ff eb 0f 00", "FL014" },
    }

    for _, case in ipairs(cases) do
      assert_problem(case[1], case[2], "invalid code length repeat", 0)
    end
  end)

  it("rejects a first-entry repeat and a repeat that crosses the total length", function()
    assert_problem("05 00 12 00", "FL014", "invalid code length repeat", 0)
    assert_problem("05 00 02 24", "FL014", "invalid code length repeat", 0)
  end)

  it("reads the accepted dynamic header metadata and transmitted lengths", function()
    local header = read_header(
      "78 da 75 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e "
        .. "8e d1 ea ab 09 b4 46 4c a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 "
        .. "1b 7d 82 3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b 65 04 "
        .. "99 55 59 66 dc 0c 4f 2f f6",
      16,
      19
    )

    assert.are.equal(271, header.hlit)
    assert.are.equal(12, header.hdist)
    assert.are.equal(18, header.hclen)
    assert.are.same({
      { 16, 0 },
      { 17, 5 },
      { 18, 3 },
      { 0, 2 },
      { 8, 0 },
      { 7, 0 },
      { 9, 0 },
      { 6, 2 },
      { 10, 0 },
      { 5, 3 },
      { 11, 0 },
      { 4, 3 },
      { 12, 0 },
      { 3, 5 },
      { 13, 0 },
      { 2, 5 },
      { 14, 0 },
      { 1, 5 },
    }, header.cl_lengths)
    assert.are.equal(271, #header.lit_lengths)
    assert.are.equal(12, #header.dist_lengths)
    assert.are.same({ used = 28, max = 6, status = "complete" }, header.lit_info)
    assert.are.same({ used = 3, max = 2, status = "complete" }, header.dist_info)
  end)

  it("preserves literal and distance lengths at the specified nonzero symbols", function()
    local header = read_header(
      "78 da 75 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e "
        .. "8e d1 ea ab 09 b4 46 4c a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 "
        .. "1b 7d 82 3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b 65 04 "
        .. "99 55 59 66 dc 0c 4f 2f f6",
      16,
      19
    )
    local literals = {
      { 32, 3 },
      { 44, 6 },
      { 46, 6 },
      { 73, 6 },
      { 97, 5 },
      { 98, 5 },
      { 99, 6 },
      { 100, 6 },
      { 101, 3 },
      { 102, 5 },
      { 103, 6 },
      { 104, 4 },
      { 105, 4 },
      { 108, 5 },
      { 109, 5 },
      { 110, 6 },
      { 111, 4 },
      { 112, 6 },
      { 114, 6 },
      { 115, 4 },
      { 116, 4 },
      { 119, 5 },
      { 256, 6 },
      { 258, 5 },
      { 264, 6 },
      { 266, 6 },
      { 269, 6 },
      { 270, 6 },
    }
    local distances = { { 9, 1 }, { 10, 2 }, { 11, 2 } }

    for _, entry in ipairs(literals) do
      assert.are.equal(entry[2], header.lit_lengths[entry[1] + 1], entry[1])
    end
    for _, entry in ipairs(distances) do
      assert.are.equal(entry[2], header.dist_lengths[entry[1] + 1], entry[1])
    end
    assert.are.equal(0, header.lit_lengths[1])
    assert.are.equal(0, header.dist_lengths[1])
    assert.are.same({
      [32] = 3,
      [44] = 6,
      [46] = 6,
      [73] = 6,
      [97] = 5,
      [98] = 5,
      [99] = 6,
      [100] = 6,
      [101] = 3,
      [102] = 5,
      [103] = 6,
      [104] = 4,
      [105] = 4,
      [108] = 5,
      [109] = 5,
      [110] = 6,
      [111] = 4,
      [112] = 6,
      [114] = 6,
      [115] = 4,
      [116] = 4,
      [119] = 5,
      [256] = 6,
      [258] = 5,
      [264] = 6,
      [266] = 6,
      [269] = 6,
      [270] = 6,
    }, nonzero_lengths(header.lit_lengths))
    assert.are.same({ [9] = 1, [10] = 2, [11] = 2 }, nonzero_lengths(header.dist_lengths))
  end)

  it("accepts repeat endpoints, zero repeats and repeats crossing HLIT", function()
    local header = read_header(
      "0d c8 d9 0e 00 00 00 40 a0 ff ff 80 f7 87 dd f7 7d df f7 7d df f7 7d df f7 7d " .. "b4 e3 06"
    )

    assert.are.equal(258, header.hlit)
    assert.are.equal(9, header.hdist)
    assert.are.equal(18, header.hclen)
    assert.are.equal(258, #header.lit_lengths)
    assert.are.equal(9, #header.dist_lengths)
    assert.are.same({ [256] = 1 }, nonzero_lengths(header.lit_lengths))
    assert.are.same({}, nonzero_lengths(header.dist_lengths))
    assert.are.same({ used = 1, max = 1, status = "incomplete" }, header.lit_info)
    assert.are.same({ used = 0, max = 0, status = "empty" }, header.dist_info)
  end)

  it("accepts a single-bit distance tree and rejects a longer incomplete one", function()
    local single = read_header("05 c0 d9 0e 00 00 00 40 a0 ff ff eb 02")
    assert.are.same({ [256] = 1 }, nonzero_lengths(single.lit_lengths))
    assert.are.same({ [0] = 1 }, nonzero_lengths(single.dist_lengths))
    assert.are.same({ used = 1, max = 1, status = "incomplete" }, single.dist_info)

    assert_problem(
      "05 c0 d9 0e 00 00 00 40 a0 ff ff eb 00",
      "FL017",
      "distance code is incomplete",
      0
    )
  end)

  it("prioritizes a missing EOB, then literal-tree errors over distance-tree errors", function()
    assert_problem(
      "05 c2 d9 0e 00 00 00 40 a0 ff ff e8 6a 15",
      "FL015",
      "no end-of-block code (symbol 256 has length 0)",
      0
    )
    assert_problem(
      "1d c2 d9 0e 00 00 00 40 a0 ea ff 3f ba 6d 15",
      "FL016",
      "literal/length code is over-subscribed",
      0
    )
  end)
end)
