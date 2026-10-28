local Decoder = require("flatelens.inflate.decoder")
local DynamicHeader = require("flatelens.inflate.header")
local Problem = require("flatelens.model.problem")

local function bytes(hex)
  return (
    hex:gsub("%s", ""):gsub("%x%x", function(pair)
      return string.char(tonumber(pair, 16))
    end)
  )
end

-- Formats the returned symbol lengths as the tree summary's nonzero runs.
local function length_summary(lengths)
  local entries = {}
  local symbol = 0

  while symbol < #lengths do
    local length = lengths[symbol + 1]
    if length == 0 then
      symbol = symbol + 1
    else
      local last = symbol
      while last + 1 < #lengths and lengths[last + 2] == length do
        last = last + 1
      end

      if last == symbol then
        entries[#entries + 1] = string.format("%d:%d", symbol, length)
      else
        entries[#entries + 1] = string.format("%d-%d:%d", symbol, last, length)
      end
      symbol = last + 1
    end
  end

  if #entries == 0 then
    return "none"
  end
  return table.concat(entries, " ")
end

local function run_problem(hex, start_bit, code, text, pos)
  local blocks, output, ending, problem = Decoder.run(bytes(hex), start_bit or 0)

  assert.is_true(Problem.is(problem))
  assert.are.equal(code, problem.code)
  assert.are.equal(text, problem.text)
  assert.are.equal(pos, problem.pos)
  return blocks, output, ending
end

describe("flatelens.inflate.decoder", function()
  it("decodes the supplied dynamic stream and copies all header metadata", function()
    local hex = table.concat({
      "78 da 75 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e ",
      "8e d1 ea ab 09 b4 46 4c a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 ",
      "1b 7d 82 3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b 65 04 ",
      "99 55 59 66 dc 0c 4f 2f f6",
    })
    local blocks, output, ending, problem = Decoder.run(bytes(hex), 16)
    local block = blocks[1]

    assert.is_nil(problem)
    assert.are.equal(
      "It was the best of times, it was the worst of times, it was the age of wisdom, "
        .. "it was the age of foolishness, it was the epoch of belief. ",
      output
    )
    assert.are.equal(138, #output)
    assert.are.equal(1, #blocks)
    assert.are.equal("dynamic", block.kind)
    assert.is_true(block.final)
    assert.are.equal(16, block.start)
    assert.are.equal(600, block.stop)
    assert.are.equal(600, ending)
    assert.are.equal(138, block.out)
    assert.are.equal(62, block.lit)
    assert.are.equal(6, block.match)
    assert.are.equal(271, block.hlit)
    assert.are.equal(12, block.hdist)
    assert.are.equal(18, block.hclen)
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
    }, block.cl_lengths)
    assert.are.same({
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      3,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      6,
      0,
      6,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      6,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      5,
      5,
      6,
      6,
      3,
      5,
      6,
      4,
      4,
      0,
      0,
      5,
      5,
      6,
      4,
      6,
      0,
      6,
      4,
      4,
      0,
      0,
      5,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      6,
      0,
      5,
      0,
      0,
      0,
      0,
      0,
      6,
      0,
      6,
      0,
      0,
      6,
      6,
    }, block.lit_lengths)
    assert.are.same({
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      1,
      2,
      2,
    }, block.dist_lengths)
    assert.are.same({ used = 28, max = 6, status = "complete" }, block.lit_info)
    assert.are.same({ used = 3, max = 2, status = "complete" }, block.dist_info)
    assert.are.equal(
      "32:3 44:6 46:6 73:6 97-98:5 99-100:6 101:3 102:5 103:6 104-105:4 "
        .. "108-109:5 110:6 111:4 112:6 114:6 115-116:4 119:5 256:6 258:5 "
        .. "264:6 266:6 269-270:6",
      length_summary(block.lit_lengths)
    )
    assert.are.equal("9:1 10-11:2", length_summary(block.dist_lengths))
  end)

  it("decodes stored, fixed and mixed blocks with exact counts and stop positions", function()
    local stored, stored_out, stored_end, stored_problem =
      Decoder.run(bytes("01 03 00 fc ff 61 62 63"), 0)
    assert.is_nil(stored_problem)
    assert.are.equal("abc", stored_out)
    assert.are.equal(64, stored_end)
    assert.are.same({
      kind = "stored",
      final = true,
      start = 0,
      stop = 64,
      lit = 0,
      match = 0,
      out = 3,
    }, stored[1])

    local fixed, fixed_out, fixed_end, fixed_problem = Decoder.run(bytes("cb 48 cd c9 c9 07 00"), 0)
    assert.is_nil(fixed_problem)
    assert.are.equal("hello", fixed_out)
    assert.are.equal(56, fixed_end)
    assert.are.same({
      kind = "fixed",
      final = true,
      start = 0,
      stop = 50,
      lit = 5,
      match = 0,
      out = 5,
    }, fixed[1])

    local mixed, mixed_out, mixed_end, mixed_problem =
      Decoder.run(bytes("00 04 00 fb ff 61 61 61 61 00 00 00 ff ff 4b 4a 82 00 00"), 0)
    assert.is_nil(mixed_problem)
    assert.are.equal("aaaabbbbbbbb", mixed_out)
    assert.are.equal(152, mixed_end)
    assert.are.same({
      { kind = "stored", final = false, start = 0, stop = 72, lit = 0, match = 0, out = 4 },
      { kind = "stored", final = false, start = 72, stop = 112, lit = 0, match = 0, out = 0 },
      { kind = "fixed", final = true, start = 112, stop = 150, lit = 2, match = 1, out = 8 },
    }, mixed)
    assert.are.same(
      { 112, 150, 8, 2, 1 },
      { mixed[3].start, mixed[3].stop, mixed[3].out, mixed[3].lit, mixed[3].match },
      "(112,150,8,2,1)"
    )
  end)

  it("aligns non-byte-started stored blocks and ignores bytes after a final block", function()
    local blocks, output, ending, problem = Decoder.run(bytes("08 03 00 fc ff 61 62 63"), 3)
    assert.is_nil(problem)
    assert.are.equal("abc", output)
    assert.are.equal(64, ending)
    assert.are.same({
      kind = "stored",
      final = true,
      start = 3,
      stop = 64,
      lit = 0,
      match = 0,
      out = 3,
    }, blocks[1])

    local trailing, trailing_out, trailing_end, trailing_problem =
      Decoder.run(bytes("cb 48 cd c9 c9 07 00 ff 00"), 0)
    assert.is_nil(trailing_problem)
    assert.are.equal("hello", trailing_out)
    assert.are.equal(56, trailing_end)
    assert.are.equal(1, #trailing)
  end)

  it("reports stored, reserved-type, symbol 286 and history errors exactly", function()
    local cases = {
      {
        "07",
        0,
        "FL010",
        "reserved block type 3",
        0,
      },
      {
        "01 03 00 fc fe 61 62 63",
        0,
        "FL011",
        "stored block length check failed: LEN 3, NLEN 65276",
        0,
      },
      { "1b 03", 0, "FL018", "invalid literal/length code", 3, "" },
      { "03 3e", 0, "FL019", "invalid distance code", 10 },
      {
        "03 02 00",
        0,
        "FL020",
        "distance 1 is more than the 0 bytes written so far",
        10,
      },
      { "78 9c cb 48", 16, "FL001", "unexpected end of data", 32, "h" },
      {
        "1b 07",
        0,
        "FL018",
        "invalid literal/length code",
        3,
      },
      {
        "73 04 3e",
        0,
        "FL019",
        "invalid distance code",
        18,
        "A",
      },
      {
        "73 04 7e",
        0,
        "FL019",
        "invalid distance code",
        18,
        "A",
      },
    }

    for _, case in ipairs(cases) do
      local blocks, output = run_problem(case[1], case[2], case[3], case[4], case[5])
      assert.are.equal(0, #blocks)
      assert.are.equal(case[6] or "", output, case[1])
    end
  end)

  it("routes all supplied malformed dynamic headers through the decoder", function()
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
      {
        "05 00",
        "FL001",
        "unexpected end of data",
        16,
      },
      {
        "05 00 00",
        "FL001",
        "unexpected end of data",
        24,
      },
      {
        "05 c0 81 04 00 00 00 00 80",
        "FL001",
        "unexpected end of data",
        72,
      },
    }

    for _, case in ipairs(cases) do
      local pos = case[4] or 0
      local blocks, output = run_problem(case[1], 0, case[2], case[3], pos)
      assert.are.equal(0, #blocks)
      assert.are.equal("", output)
    end
  end)

  it("handles overlap, extra bits and symbol 285's 258-byte match", function()
    local blocks, output, ending, problem = Decoder.run(bytes("9b 30 61 c2 84 09 13 90 49 00"), 0)
    assert.is_nil(problem)
    assert.are.equal(18, #output)
    assert.are.same({
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
      144,
    }, { output:byte(1, #output) })
    assert.are.equal(0x90, output:byte(1))
    assert.are.equal(0x90, output:byte(18))
    assert.are.equal(1, #blocks)
    assert.are.equal(6, blocks[1].lit)
    assert.are.equal(1, blocks[1].match)
    assert.are.equal(18, blocks[1].out)
    assert.are.equal(80, ending)

    local longest, longest_out, longest_end, longest_problem = Decoder.run(bytes("73 1c 05 00"), 0)
    assert.is_nil(longest_problem)
    assert.are.equal(259, #longest_out)
    assert.is_true(longest_out:match("^A+$") ~= nil)
    assert.are.equal(258, longest[1].out - longest[1].lit)
    assert.are.equal(31, longest[1].stop)
    assert.are.equal(1, longest[1].lit)
    assert.are.equal(1, longest[1].match)
    assert.are.equal(259, longest[1].out)
    assert.are.equal(32, longest_end)
  end)

  it("retains history across stored, fixed and dynamic block boundaries", function()
    local stored_fixed, stored_fixed_out, stored_fixed_end, stored_fixed_problem =
      Decoder.run(bytes("00 01 00 fe ff 61 03 02 00"), 0)
    assert.is_nil(stored_fixed_problem)
    assert.are.equal("aaaa", stored_fixed_out)
    assert.are.equal(72, stored_fixed_end)
    assert.are.equal(48, stored_fixed[1].stop)
    assert.are.equal(48, stored_fixed[2].start)
    assert.are.equal(1, stored_fixed[2].match)
    assert.are.equal(3, stored_fixed[2].out)

    local fixed_fixed, fixed_fixed_out, fixed_fixed_end, fixed_fixed_problem =
      Decoder.run(bytes("72 04 0c 08 00"), 0)
    assert.is_nil(fixed_fixed_problem)
    assert.are.equal("AAAA", fixed_fixed_out)
    assert.are.equal(40, fixed_fixed_end)
    assert.are.equal(18, fixed_fixed[1].stop)
    assert.are.equal(18, fixed_fixed[2].start)
    assert.are.equal(1, fixed_fixed[2].match)
    assert.are.equal(3, fixed_fixed[2].out)

    local dynamic_fixed_hex = table.concat({
      "78 da 74 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e ",
      "8e d1 ea ab 09 b4 46 4c a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 ",
      "1b 7d 82 3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b 65 04 ",
      "99 55 59 66 dc 03 02 00",
    })
    local dynamic_fixed, dynamic_fixed_out, dynamic_fixed_end, dynamic_fixed_problem =
      Decoder.run(bytes(dynamic_fixed_hex), 16)
    assert.is_nil(dynamic_fixed_problem)
    assert.are.equal(141, #dynamic_fixed_out)
    assert.are.equal(624, dynamic_fixed_end)
    assert.are.equal("dynamic", dynamic_fixed[1].kind)
    assert.is_false(dynamic_fixed[1].final)
    assert.are.equal(16, dynamic_fixed[1].start)
    assert.are.equal(600, dynamic_fixed[1].stop)
    assert.are.equal(138, dynamic_fixed[1].out)
    assert.are.equal(62, dynamic_fixed[1].lit)
    assert.are.equal(6, dynamic_fixed[1].match)
    assert.are.equal("fixed", dynamic_fixed[2].kind)
    assert.is_true(dynamic_fixed[2].final)
    assert.are.equal(600, dynamic_fixed[2].start)
    assert.are.equal(622, dynamic_fixed[2].stop)
    assert.are.equal(0, dynamic_fixed[2].lit)
    assert.are.equal(1, dynamic_fixed[2].match)
    assert.are.equal(3, dynamic_fixed[2].out)
    assert.are.equal(
      "It was the best of times, it was the worst of times, it was the age of wisdom, "
        .. "it was the age of foolishness, it was the epoch of belief.    ",
      dynamic_fixed_out
    )
  end)

  it("accepts an empty distance tree for EOB and rejects attempts to use it", function()
    local literal_blocks, literal_output, literal_end, literal_problem =
      Decoder.run(bytes("05 ca 81 00 00 00 00 00 90 36 ff 53 02 04"), 0)
    assert.is_nil(literal_problem)
    assert.are.equal("A", literal_output)
    assert.are.equal(112, literal_end)
    assert.are.equal(1, #literal_blocks)
    assert.are.equal(107, literal_blocks[1].stop)
    assert.are.equal(1, literal_blocks[1].lit)
    assert.are.equal(0, literal_blocks[1].match)
    assert.are.equal(1, literal_blocks[1].out)
    assert.are.same({ used = 0, max = 0, status = "empty" }, literal_blocks[1].dist_info)

    local blocks, output, ending, problem =
      Decoder.run(bytes("0d c0 01 09 00 00 00 00 90 ff af 09"), 0)
    assert.is_nil(problem)
    assert.are.equal("", output)
    assert.are.equal(96, ending)
    assert.are.equal(1, #blocks)
    assert.are.equal(94, blocks[1].stop)
    assert.are.same({ used = 0, max = 0, status = "empty" }, blocks[1].dist_info)
    assert.are.equal(0, blocks[1].lit)
    assert.are.equal(0, blocks[1].match)
    assert.are.equal(0, blocks[1].out)

    local bad_blocks, bad_output = run_problem(
      "0d c0 01 09 00 00 00 00 90 ff af 29 00 00",
      0,
      "FL019",
      "invalid distance code",
      94
    )
    assert.are.equal(0, #bad_blocks)
    assert.are.equal("", bad_output)
  end)

  it("distinguishes an unmatched 15-bit literal path from early EOF", function()
    local blocks, output, ending, problem =
      Decoder.run(bytes("05 c0 81 00 00 00 00 00 90 ff 6b fe ff"), 0)
    assert.is_true(Problem.is(problem))
    assert.are.equal("FL018", problem.code)
    assert.are.equal("invalid literal/length code", problem.text)
    assert.are.equal(89, problem.pos)
    assert.are.equal(104, ending)
    assert.are.equal(0, #blocks)
    assert.are.equal("", output)

    local short_blocks, short_output, short_end, short_problem =
      Decoder.run(bytes("05 c0 81 00 00 00 00 00 90 ff 6b fe"), 0)
    assert.is_true(Problem.is(short_problem))
    assert.are.equal("FL001", short_problem.code)
    assert.are.equal("unexpected end of data", short_problem.text)
    assert.are.equal(96, short_problem.pos)
    assert.are.equal(96, short_end)
    assert.are.equal(0, #short_blocks)
    assert.are.equal("", short_output)
  end)

  it("preserves completed blocks and partial bytes on fatal truncations", function()
    local cases = {
      { "", 0, 0, "", 0 },
      { "01", 8, 0, "", 8 },
      { "01 03 00", 24, 0, "", 24 },
      { "01 03 00 fc ff 61 62", 56, 0, "ab", 56 },
      { "05 00", 16, 0, "", 13 },
      { "05 00 00", 24, 0, "", 23 },
      { "05 c0 81 04 00 00 00 00 80", 72, 0, "", 72 },
      { "9b 30 61 c2 84 09 13 90", 64, 0, "\144\144\144\144\144\144", 64 },
      { "9b 00 24", 24, 0, "\144", 24 },
      {
        "00 01 00 fe ff 78 01 03 00 fc ff 61",
        96,
        1,
        "xa",
        96,
      },
    }

    for _, case in ipairs(cases) do
      local blocks, output, ending, problem = Decoder.run(bytes(case[1]), 0)
      assert.is_true(Problem.is(problem))
      assert.are.equal("FL001", problem.code)
      assert.are.equal("unexpected end of data", problem.text)
      assert.are.equal(case[2], problem.pos)
      assert.are.equal(case[3], #blocks)
      assert.are.equal(case[4], output)
      assert.are.equal(case[5], ending)
    end

    local first = Decoder.run(bytes("00 01 00 fe ff 78 07"), 0)
    assert.are.equal(1, #first)
    assert.are.equal("x", select(2, Decoder.run(bytes("00 01 00 fe ff 78 07"), 0)))
  end)

  it("returns typed Problem identity and rethrows unrelated errors unchanged", function()
    local original_read = DynamicHeader.read
    local typed = Problem.bad_repeat(24)
    DynamicHeader.read = function()
      error(typed, 0)
    end
    local typed_ok, blocks, output, ending, caught = pcall(function()
      return Decoder.run(bytes("05 00 00 00"), 0)
    end)
    DynamicHeader.read = original_read

    assert.is_true(typed_ok)
    assert.are.equal(0, #blocks)
    assert.are.equal("", output)
    assert.are.equal(3, ending)
    assert.is_true(rawequal(typed, caught))

    local unrelated = { reason = "must be rethrown" }
    DynamicHeader.read = function()
      error(unrelated, 0)
    end
    local unrelated_ok, error_value = pcall(function()
      Decoder.run(bytes("05 00 00 00"), 0)
    end)
    DynamicHeader.read = original_read

    assert.is_false(unrelated_ok)
    assert.is_true(rawequal(unrelated, error_value))
  end)
end)
