local Decoder = require("flatelens.inflate.decoder")
local Gzip = require("flatelens.frame.gzip")
local Problem = require("flatelens.model.problem")
local Stream = require("flatelens.frame.stream")
local Zlib = require("flatelens.frame.zlib")

local function bytes(text)
  return (
    text:gsub("%s", ""):gsub("%x%x", function(pair)
      return string.char(tonumber(pair, 16))
    end)
  )
end

local function with_replaced(target, key, replacement, callback)
  local original = target[key]
  target[key] = replacement
  local ok, value = pcall(callback)
  target[key] = original
  if not ok then
    error(value, 0)
  end
  return value
end

local named_gzip = bytes(table.concat({
  "1f 8b 08 1c 00 f1 53 65 00 03 02 00 61 62 ",
  "68 65 6c 6c 6f 2e 74 78 74 00 61 20 22 6e 6f 74 65 22 01 00 ",
  "cb 48 cd c9 c9 57 c8 40 90 5c 00 3b 7c 8a df 12 00 00 00",
}))

describe("Stream", function()
  it("detects auto formats by the exact signatures and checks", function()
    local cases = {
      { "", "raw", "FL001" },
      { "78", "raw", "FL001" },
      { "1f 8b", "gzip", "FL001" },
      { "78 9c", "zlib", "FL001" },
      { "88 1c", "zlib", "FL005" },
      { "78 9d", "raw", "FL001" },
      { "79 18", "raw", "FL001" },
      { "07", "raw", "FL010" },
    }

    for _, case in ipairs(cases) do
      local report = Stream.analyse(bytes(case[1]), "auto")
      assert.are.equal(case[2], report.format, case[1])
      assert.are.equal(case[3], report.problems[1].code, case[1])
      assert.is_true(Problem.is(report.problems[1]), case[1])
    end
  end)

  it("honors forced gzip, zlib, and raw formats", function()
    local gzip_report = Stream.analyse(bytes("78 9c cb 48 cd c9 c9 07 00 06 2c 02 15"), "gzip")
    assert.are.equal("gzip", gzip_report.format)
    assert.are.equal("FL008", gzip_report.problems[1].code)
    assert.are.equal(0, gzip_report.cstart)
    assert.are.same({}, gzip_report.header)

    local zlib_report = Stream.analyse(bytes("78 9d cb 48 cd c9 c9 07 00 06 2c 02 15"), "zlib")
    assert.are.equal("zlib", zlib_report.format)
    assert.are.equal("FL004", zlib_report.problems[1].code)
    assert.are.equal("zlib header check failed", zlib_report.problems[1].text)

    local raw_report = Stream.analyse(bytes("cb 48 cd c9 c9 07 00"), "raw")
    assert.are.equal("raw", raw_report.format)
    assert.are.equal("hello", raw_report.out)
    assert.are.equal("none", raw_report.check)
    assert.are.same({}, raw_report.header)
  end)

  it("returns the complete literal hello zlib report and rounds its endpoint", function()
    local report = Stream.analyse(bytes("78 9c cb 48 cd c9 c9 07 00 06 2c 02 15"), "auto")

    assert.are.same({
      format = "zlib",
      header = { "window: 32768 bytes", "level: default" },
      blocks = {
        {
          kind = "fixed",
          final = true,
          start = 16,
          stop = 66,
          lit = 5,
          match = 0,
          out = 5,
        },
      },
      out = "hello",
      problems = {},
      fatal = false,
      cstart = 2,
      cend = 9,
      check = "adler32 ok",
      trailing = 0,
    }, report)
  end)

  it("returns the complete named gzip report with optional metadata", function()
    local report = Stream.analyse(named_gzip, "auto")

    assert.are.equal("gzip", report.format)
    assert.are.same({
      "mtime: 1700000000",
      "os: unix",
      'name: "hello.txt"',
      'comment: "a \\"note\\"\\x01"',
      "extra: 2 bytes",
    }, report.header)
    assert.are.equal("hello hello hello\n", report.out)
    assert.are.equal(1, #report.blocks)
    assert.are.same({
      kind = "fixed",
      final = true,
      start = 272,
      stop = 359,
      lit = 8,
      match = 1,
      out = 18,
    }, {
      kind = report.blocks[1].kind,
      final = report.blocks[1].final,
      start = report.blocks[1].start,
      stop = report.blocks[1].stop,
      lit = report.blocks[1].lit,
      match = report.blocks[1].match,
      out = report.blocks[1].out,
    })
    assert.are.equal(34, report.cstart)
    assert.are.equal(45, report.cend)
    assert.are.equal("crc32 ok, size ok", report.check)
    assert.are.same({}, report.problems)
    assert.is_false(report.fatal)
    assert.are.equal(0, report.trailing)
  end)

  it("reports a dynamic text stream and mixed raw blocks without losing metadata", function()
    local dynamic_data = bytes("78 da " .. table.concat({
      "75 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e 8e d1 ea ab 09 b4 46 4c ",
      "a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 1b 7d 82 ",
      "3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b ",
      "65 04 99 55 59 66 dc 0c 4f 2f f6",
    }))
    local dynamic = Stream.analyse(dynamic_data, "auto")

    assert.are.equal("zlib", dynamic.format)
    assert.are.same({ "window: 32768 bytes", "level: maximum" }, dynamic.header)
    assert.are.equal(2, dynamic.cstart)
    assert.are.equal(75, dynamic.cend)
    assert.are.equal("adler32 ok", dynamic.check)
    assert.are.equal(
      "It was the best of times, it was the worst of times, it was the age of wisdom, "
        .. "it was the age of foolishness, it was the epoch of belief. ",
      dynamic.out
    )
    assert.are.equal(1, #dynamic.blocks)
    assert.are.equal("dynamic", dynamic.blocks[1].kind)
    assert.is_true(dynamic.blocks[1].final)
    assert.are.equal(16, dynamic.blocks[1].start)
    assert.are.equal(600, dynamic.blocks[1].stop)
    assert.are.equal(138, dynamic.blocks[1].out)
    assert.are.equal(62, dynamic.blocks[1].lit)
    assert.are.equal(6, dynamic.blocks[1].match)
    assert.are.equal(271, dynamic.blocks[1].hlit)
    assert.are.equal(12, dynamic.blocks[1].hdist)
    assert.are.equal(18, dynamic.blocks[1].hclen)
    assert.are.same({ used = 28, max = 6, status = "complete" }, dynamic.blocks[1].lit_info)
    assert.are.same({ used = 3, max = 2, status = "complete" }, dynamic.blocks[1].dist_info)
    assert.are.same({}, dynamic.problems)
    assert.is_false(dynamic.fatal)
    assert.are.equal(0, dynamic.trailing)

    local mixed =
      Stream.analyse(bytes("00 04 00 fb ff 61 61 61 61 00 00 00 ff ff 4b 4a 82 00 00"), "raw")
    assert.are.same({
      format = "raw",
      header = {},
      blocks = {
        { kind = "stored", final = false, start = 0, stop = 72, lit = 0, match = 0, out = 4 },
        { kind = "stored", final = false, start = 72, stop = 112, lit = 0, match = 0, out = 0 },
        { kind = "fixed", final = true, start = 112, stop = 150, lit = 2, match = 1, out = 8 },
      },
      out = "aaaabbbbbbbb",
      problems = {},
      fatal = false,
      cstart = 0,
      cend = 19,
      check = "none",
      trailing = 0,
    }, mixed)
  end)

  it("keeps the full report schema for a valid zero-output zlib stream", function()
    local report = Stream.analyse(bytes("78 9c 03 00 00 00 00 01"), "auto")

    assert.are.same({
      format = "zlib",
      header = { "window: 32768 bytes", "level: default" },
      blocks = {
        { kind = "fixed", final = true, start = 16, stop = 26, lit = 0, match = 0, out = 0 },
      },
      out = "",
      problems = {},
      fatal = false,
      cstart = 2,
      cend = 4,
      check = "adler32 ok",
      trailing = 0,
    }, report)
  end)

  it("preserves typed fatal header problems and stops before decoding", function()
    local decoder_calls = 0
    with_replaced(Decoder, "run", function()
      decoder_calls = decoder_calls + 1
      error("decoder must not run", 0)
    end, function()
      local cases = {
        { "1f 8b 07 00 00 00 00 00 00 03", "auto", "FL002", "unsupported compression method 7", 0 },
        {
          "1f 8b 08 20 00 00 00 00 00 03",
          "auto",
          "FL003",
          "reserved gzip flag bits set: 0x20",
          0,
        },
        { "78 20 01 02 03 04 cb 48", "auto", "FL006", "zlib preset dictionary required", 0 },
        { "1f 8b", "auto", "FL001", "unexpected end of data", 16 },
      }

      for _, case in ipairs(cases) do
        local report = Stream.analyse(bytes(case[1]), case[2])
        assert.are.equal(case[3], report.problems[1].code, case[1])
        assert.are.equal(case[4], report.problems[1].text, case[1])
        assert.are.equal(case[5], report.problems[1].pos, case[1])
        assert.are.same({}, report.blocks)
        assert.are.equal("", report.out)
        assert.is_true(report.fatal)
        assert.are.equal(0, report.cstart)
        assert.are.equal(0, report.cend)
        assert.is_nil(report.check)
        assert.are.equal(0, report.trailing)
      end
    end)
    assert.are.equal(0, decoder_calls)
  end)

  it("preserves completed blocks and partial output on fatal decoder errors", function()
    local completed = Stream.analyse(bytes("78 9c 00 01 00 fe ff 78"), "zlib")
    assert.are.same({ "window: 32768 bytes", "level: default" }, completed.header)
    assert.are.equal(2, completed.cstart)
    assert.are.equal(8, completed.cend)
    assert.are.equal("x", completed.out)
    assert.are.equal(1, #completed.blocks)
    assert.are.equal("stored", completed.blocks[1].kind)
    assert.are.equal(1, completed.blocks[1].out)
    assert.is_true(completed.fatal)
    assert.is_nil(completed.check)
    assert.are.equal(1, #completed.problems)
    assert.are.equal("FL001", completed.problems[1].code)
    assert.are.equal("unexpected end of data", completed.problems[1].text)
    assert.are.equal(64, completed.problems[1].pos)

    local trailer_calls = 0
    with_replaced(Zlib, "trailer", function()
      trailer_calls = trailer_calls + 1
      error("trailer must not run", 0)
    end, function()
      local stopped = Stream.analyse(bytes("78 9c 07"), "zlib")
      assert.is_true(stopped.fatal)
      assert.are.equal("FL010", stopped.problems[1].code)
      assert.are.equal(2, stopped.cstart)
      assert.are.equal(3, stopped.cend)
      assert.are.same({}, stopped.blocks)
      assert.are.equal("", stopped.out)
      assert.is_nil(stopped.check)
    end)
    assert.are.equal(0, trailer_calls)
  end)

  it("reports fatal truncated trailers after retaining decoded data and offsets", function()
    local zlib = Stream.analyse(bytes("78 9c cb 48 cd c9 c9 07 00 06 2c 02"), "zlib")
    assert.are.equal(9, zlib.cend)
    assert.are.equal("hello", zlib.out)
    assert.is_true(zlib.fatal)
    assert.is_nil(zlib.check)
    assert.are.equal(1, #zlib.blocks)
    assert.are.equal("fixed", zlib.blocks[1].kind)
    assert.are.equal("FL001", zlib.problems[1].code)
    assert.are.equal("unexpected end of data", zlib.problems[1].text)
    assert.are.equal(96, zlib.problems[1].pos)

    local gzip_bytes = bytes(table.concat({
      "1f 8b 08 00 00 00 00 00 00 03 cb 48 cd c9 c9 07 00 ",
      "3b 7c 8a df",
    }))
    local gzip = Stream.analyse(gzip_bytes, "gzip")
    assert.are.equal(17, gzip.cend)
    assert.are.equal("hello", gzip.out)
    assert.is_true(gzip.fatal)
    assert.are.equal("FL001", gzip.problems[1].code)
    assert.are.equal(168, gzip.problems[1].pos)
    assert.is_nil(gzip.check)
  end)

  it("reports trailing bytes after raw, zlib, gzip, and concatenated gzip input", function()
    local raw_zero = Stream.analyse(bytes("cb 48 cd c9 c9 07 00"), "raw")
    assert.are.equal(0, raw_zero.trailing)
    assert.are.same({}, raw_zero.problems)

    local raw_one = Stream.analyse(bytes("cb 48 cd c9 c9 07 00 ff"), "raw")
    assert.are.equal(1, raw_one.trailing)
    assert.are.equal("FL023", raw_one.problems[1].code)
    assert.are.equal("1 byte after the end of the stream", raw_one.problems[1].text)
    assert.are.equal(56, raw_one.problems[1].pos)

    local zlib_many = Stream.analyse(bytes("78 9c cb 48 cd c9 c9 07 00 06 2c 02 15 aa bb"), "zlib")
    assert.are.equal(2, zlib_many.trailing)
    assert.are.equal("2 bytes after the end of the stream", zlib_many.problems[1].text)
    assert.are.equal(104, zlib_many.problems[1].pos)

    local gzip_member = named_gzip
    local gzip_zero = Stream.analyse(gzip_member, "gzip")
    assert.are.equal(0, gzip_zero.trailing)
    assert.are.same({}, gzip_zero.problems)

    local gzip_one = Stream.analyse(gzip_member .. bytes("ff"), "gzip")
    assert.are.equal(1, gzip_one.trailing)
    assert.are.equal(424, gzip_one.problems[1].pos)

    local zlib_zero = Stream.analyse(bytes("78 9c cb 48 cd c9 c9 07 00 06 2c 02 15"), "zlib")
    assert.are.equal(0, zlib_zero.trailing)
    assert.are.same({}, zlib_zero.problems)

    local concatenated = Stream.analyse(gzip_member .. gzip_member, "gzip")
    assert.are.equal(53, concatenated.trailing)
    assert.are.equal(1, #concatenated.blocks)
    assert.are.equal("FL023", concatenated.problems[1].code)
    assert.are.equal(424, concatenated.problems[1].pos)
  end)

  it("orders checksum, size, and trailing diagnostics for nonfatal mismatches", function()
    local zlib = Stream.analyse(bytes("78 9c cb 48 cd c9 c9 07 00 06 2c 02 14"), "zlib")
    assert.are.equal("adler32 mismatch", zlib.check)
    assert.are.equal(1, #zlib.problems)
    assert.are.equal("FL021", zlib.problems[1].code)
    assert.are.equal(
      "Adler-32 mismatch: stored 0x062c0214, computed 0x062c0215",
      zlib.problems[1].text
    )
    assert.are.equal(72, zlib.problems[1].pos)
    assert.is_false(zlib.fatal)

    local invalid = named_gzip:sub(1, 45) .. bytes("01 00 00 00 13 00 00 00 aa bb")
    local gzip = Stream.analyse(invalid, "gzip")
    assert.are.equal("crc32 mismatch, size mismatch", gzip.check)
    assert.are.same({ "FL021", "FL022", "FL023" }, {
      gzip.problems[1].code,
      gzip.problems[2].code,
      gzip.problems[3].code,
    })
    assert.are.equal(
      "CRC-32 mismatch: stored 0x00000001, computed 0xdf8a7c3b",
      gzip.problems[1].text
    )
    assert.are.equal("size mismatch: stored 19, computed 18", gzip.problems[2].text)
    assert.are.equal("2 bytes after the end of the stream", gzip.problems[3].text)
    assert.are.same({ 360, 360, 424 }, {
      gzip.problems[1].pos,
      gzip.problems[2].pos,
      gzip.problems[3].pos,
    })
    assert.is_false(gzip.fatal)
  end)

  it(
    "rounds injected non-byte endpoints and rethrows unrelated dependency errors by identity",
    function()
      local original_run = Decoder.run
      Decoder.run = function(_data, start_bit)
        assert.are.equal(0, start_bit)
        return {}, "stub", 3, nil
      end
      local rounded_ok, rounded = pcall(Stream.analyse, bytes("00 aa bb"), "raw")
      Decoder.run = original_run

      assert.is_true(rounded_ok)
      assert.are.equal("stub", rounded.out)
      assert.are.equal(1, rounded.cend)
      assert.are.equal(2, rounded.trailing)
      assert.are.equal("FL023", rounded.problems[1].code)
      assert.are.equal("2 bytes after the end of the stream", rounded.problems[1].text)
      assert.are.equal(8, rounded.problems[1].pos)

      local container_error = { reason = "container sentinel" }
      with_replaced(Gzip, "header", function()
        error(container_error, 0)
      end, function()
        local ok, value = pcall(Stream.analyse, bytes("1f 8b 08 00 00 00 00 00 00 03"), "gzip")
        assert.is_false(ok)
        assert.is_true(rawequal(container_error, value))
      end)

      local decoder_error = { reason = "decoder sentinel" }
      with_replaced(Decoder, "run", function()
        error(decoder_error, 0)
      end, function()
        local ok, value = pcall(Stream.analyse, bytes("cb 48 cd c9 c9 07 00"), "raw")
        assert.is_false(ok)
        assert.is_true(rawequal(decoder_error, value))
      end)
    end
  )
end)
