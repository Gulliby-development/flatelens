local Gzip = require("flatelens.frame.gzip")
local Problem = require("flatelens.model.problem")

local function from_hex(text)
  return (
    text:gsub("%s", ""):gsub("%x%x", function(pair)
      return string.char(tonumber(pair, 16))
    end)
  )
end

describe("Gzip", function()
  it("validates the fixed header in the specified order", function()
    local cases = {
      { "", "FL001", "unexpected end of data", 0 },
      { "1f", "FL001", "unexpected end of data", 8 },
      { "00 00", "FL008", "not a gzip stream", 0 },
      { "1f 8b 07 20", "FL001", "unexpected end of data", 32 },
      { "1f 8b 07 20 00 00 00 00 00 03", "FL002", "unsupported compression method 7", 0 },
      { "1f 8b 08 e1 00 00 00 00 00 03", "FL003", "reserved gzip flag bits set: 0xe0", 0 },
    }

    for _, case in ipairs(cases) do
      local ok, problem = pcall(Gzip.header, from_hex(case[1]))
      assert.is_false(ok, case[2])
      assert.is_true(Problem.is(problem), case[2])
      assert.are.equal(case[2], problem.code)
      assert.are.equal(case[3], problem.text)
      assert.are.equal(case[4], problem.pos)
    end

    local header = Gzip.header(from_hex("1f 8b 08 01 00 00 00 00 ff 03"))
    assert.are.same({ start = 10, lines = { "mtime: 0", "os: unix" } }, header)
  end)

  it("parses optional fields in wire order and presents metadata in contract order", function()
    local extra = Gzip.header(from_hex("1f 8b 08 04 00 00 00 00 00 03 00 00"))
    assert.are.equal(12, extra.start)
    assert.are.same({ "mtime: 0", "os: unix", "extra: 0 bytes" }, extra.lines)

    local one_extra = Gzip.header(from_hex("1f 8b 08 04 00 00 00 00 00 03 01 00 aa"))
    assert.are.equal(13, one_extra.start)
    assert.are.same({ "mtime: 0", "os: unix", "extra: 1 byte" }, one_extra.lines)

    local two_extra = Gzip.header(from_hex("1f 8b 08 04 00 00 00 00 00 03 02 00 aa bb"))
    assert.are.equal(14, two_extra.start)
    assert.are.same({ "mtime: 0", "os: unix", "extra: 2 bytes" }, two_extra.lines)

    local name = Gzip.header(from_hex("1f 8b 08 08 00 00 00 00 00 03 61 00"))
    assert.are.equal(12, name.start)
    assert.are.same({ "mtime: 0", "os: unix", 'name: "a"' }, name.lines)

    local comment = Gzip.header(from_hex("1f 8b 08 10 00 00 00 00 00 03 62 00"))
    assert.are.equal(12, comment.start)
    assert.are.same({ "mtime: 0", "os: unix", 'comment: "b"' }, comment.lines)

    local empty_fields = Gzip.header(from_hex("1f 8b 08 18 00 00 00 00 00 03 00 00"))
    assert.are.equal(12, empty_fields.start)
    assert.are.same({ "mtime: 0", "os: unix", 'name: ""', 'comment: ""' }, empty_fields.lines)

    local named = Gzip.header(
      from_hex(
        "1f 8b 08 1c 00 f1 53 65 00 03 02 00 61 62 68 65 6c 6c 6f 2e 74 78 74 00 "
          .. "61 20 22 6e 6f 74 65 22 01 00"
      )
    )
    assert.are.equal(34, named.start)
    assert.are.same({
      "mtime: 1700000000",
      "os: unix",
      'name: "hello.txt"',
      [[comment: "a \"note\"\x01"]],
      "extra: 2 bytes",
    }, named.lines)
  end)

  it("reports every optional-field truncation at the end of the supplied bytes", function()
    local cases = {
      { "1f 8b 08 04 00 00 00 00 00 03", 80 },
      { "1f 8b 08 04 00 00 00 00 00 03 02", 88 },
      { "1f 8b 08 04 00 00 00 00 00 03 02 00", 96 },
      { "1f 8b 08 04 00 00 00 00 00 03 02 00 aa", 104 },
      { "1f 8b 08 08 00 00 00 00 00 03 61", 88 },
      { "1f 8b 08 10 00 00 00 00 00 03 61", 88 },
      { "1f 8b 08 02 00 00 00 00 00 03", 80 },
      { "1f 8b 08 02 00 00 00 00 00 03 a7", 88 },
    }

    for _, case in ipairs(cases) do
      local data = from_hex(case[1])
      local ok, problem = pcall(Gzip.header, data)
      assert.is_false(ok)
      assert.is_true(Problem.is(problem))
      assert.are.equal("FL001", problem.code)
      assert.are.equal("unexpected end of data", problem.text)
      assert.are.equal(case[2], problem.pos)
      assert.are.equal(#data * 8, problem.pos)
    end
  end)

  it("checks FHCRC over the complete preceding header and excludes its own field", function()
    local simple = Gzip.header(from_hex("1f 8b 08 02 00 00 00 00 00 03 a7 77"))
    assert.are.equal(12, simple.start)
    assert.are.same({ "mtime: 0", "os: unix", "header crc: ok" }, simple.lines)

    local combined =
      Gzip.header(from_hex("1f 8b 08 1e 00 00 00 00 00 03 02 00 aa bb 61 00 62 00 cc 59"))
    assert.are.equal(20, combined.start)
    assert.are.same({
      "mtime: 0",
      "os: unix",
      'name: "a"',
      'comment: "b"',
      "extra: 2 bytes",
      "header crc: ok",
    }, combined.lines)

    local ok, problem = pcall(Gzip.header, from_hex("1f 8b 08 02 00 00 00 00 00 03 a6 77"))
    assert.is_false(ok)
    assert.is_true(Problem.is(problem))
    assert.are.equal("FL007", problem.code)
    assert.are.equal("gzip header CRC mismatch: stored 0x77a6, computed 0x77a7", problem.text)
    assert.are.equal(0, problem.pos)
  end)

  it("maps every defined OS value and formats fallback and unsigned metadata", function()
    local cases = {
      { "1f 8b 08 00 00 00 00 00 00 00", "fat" },
      { "1f 8b 08 00 00 00 00 00 00 01", "amiga" },
      { "1f 8b 08 00 00 00 00 00 00 02", "vms" },
      { "1f 8b 08 00 00 00 00 00 00 03", "unix" },
      { "1f 8b 08 00 00 00 00 00 00 04", "vm/cms" },
      { "1f 8b 08 00 00 00 00 00 00 05", "atari tos" },
      { "1f 8b 08 00 00 00 00 00 00 06", "hpfs" },
      { "1f 8b 08 00 00 00 00 00 00 07", "macintosh" },
      { "1f 8b 08 00 00 00 00 00 00 08", "z-system" },
      { "1f 8b 08 00 00 00 00 00 00 09", "cp/m" },
      { "1f 8b 08 00 00 00 00 00 00 0a", "tops-20" },
      { "1f 8b 08 00 00 00 00 00 00 0b", "ntfs" },
      { "1f 8b 08 00 00 00 00 00 00 0c", "qdos" },
      { "1f 8b 08 00 00 00 00 00 00 0d", "acorn riscos" },
      { "1f 8b 08 00 00 00 00 00 00 ff", "unknown" },
      { "1f 8b 08 00 00 00 00 00 00 0e", "other (14)" },
    }

    for _, case in ipairs(cases) do
      local header = Gzip.header(from_hex(case[1]))
      assert.are.equal(10, header.start, case[2])
      assert.are.same({ "mtime: 0", "os: " .. case[2] }, header.lines, case[2])
    end

    local unsigned_mtime = Gzip.header(from_hex("1f 8b 08 00 ff ff ff ff 00 0e"))
    assert.are.same({ "mtime: 4294967295", "os: other (14)" }, unsigned_mtime.lines)
  end)

  it("escapes binary names and comments while retaining printable bytes", function()
    local header =
      Gzip.header(from_hex("1f 8b 08 18 00 00 00 00 00 03 5c 22 01 ff 00 70 6c 61 69 6e 00"))
    assert.are.equal(21, header.start)
    assert.are.same({
      "mtime: 0",
      "os: unix",
      [[name: "\\\"\x01\xff"]],
      'comment: "plain"',
    }, header.lines)
  end)

  it("validates gzip trailers and returns mismatches in CRC-then-size order", function()
    local cases = {
      {
        "86 a6 10 36 05 00 00 00",
        0,
        "hello",
        "crc32 ok, size ok",
        {},
      },
      {
        "01 00 00 00 05 00 00 00",
        0,
        "hello",
        "crc32 mismatch, size ok",
        { { "FL021", "CRC-32 mismatch: stored 0x00000001, computed 0x3610a686", 0 } },
      },
      {
        "86 a6 10 36 02 00 00 00",
        0,
        "hello",
        "crc32 ok, size mismatch",
        { { "FL022", "size mismatch: stored 2, computed 5", 0 } },
      },
      {
        "00 01 00 00 00 02 00 00 00",
        1,
        "hello",
        "crc32 mismatch, size mismatch",
        {
          { "FL021", "CRC-32 mismatch: stored 0x00000001, computed 0x3610a686", 8 },
          { "FL022", "size mismatch: stored 2, computed 5", 8 },
        },
      },
      {
        "00 00 00 00 00 00 00 00",
        0,
        "",
        "crc32 ok, size ok",
        {},
      },
    }

    for _, case in ipairs(cases) do
      local check, problems = Gzip.trailer(from_hex(case[1]), case[2], case[3])
      assert.are.equal(case[4], check)
      assert.are.equal(#case[5], #problems)
      for index, expected in ipairs(case[5]) do
        local problem = problems[index]
        assert.is_true(Problem.is(problem))
        assert.are.equal(expected[1], problem.code)
        assert.are.equal(expected[2], problem.text)
        assert.are.equal(expected[3], problem.pos)
      end
    end

    local named_data = string.rep("\0", 45) .. from_hex("01 00 00 00 02 00 00 00")
    local named_check, named_problems = Gzip.trailer(named_data, 45, "hello hello hello\n")
    assert.are.equal("crc32 mismatch, size mismatch", named_check)
    assert.are.equal(2, #named_problems)
    assert.is_true(Problem.is(named_problems[1]))
    assert.are.equal("FL021", named_problems[1].code)
    assert.are.equal(
      "CRC-32 mismatch: stored 0x00000001, computed 0xdf8a7c3b",
      named_problems[1].text
    )
    assert.are.equal(360, named_problems[1].pos)
    assert.is_true(Problem.is(named_problems[2]))
    assert.are.equal("FL022", named_problems[2].code)
    assert.are.equal("size mismatch: stored 2, computed 18", named_problems[2].text)
    assert.are.equal(360, named_problems[2].pos)
  end)

  it(
    "rejects incomplete trailers at file end and ignores bytes after a complete trailer",
    function()
      local cases = {
        { "", 0, 0 },
        { "01 00 00 00", 0, 32 },
        { "01 00 00 00 02 00 00", 0, 56 },
        { "00 01 00 00 00 02 00 00", 1, 64 },
      }

      for _, case in ipairs(cases) do
        local ok, problem = pcall(Gzip.trailer, from_hex(case[1]), case[2], "hello")
        assert.is_false(ok)
        assert.is_true(Problem.is(problem))
        assert.are.equal("FL001", problem.code)
        assert.are.equal("unexpected end of data", problem.text)
        assert.are.equal(case[3], problem.pos)
      end

      local check, problems = Gzip.trailer(from_hex("86 a6 10 36 05 00 00 00 00 00"), 0, "hello")
      assert.are.equal("crc32 ok, size ok", check)
      assert.are.equal(0, #problems)
    end
  )
end)
