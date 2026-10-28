local Problem = require("flatelens.model.problem")
local Zlib = require("flatelens.frame.zlib")

local function bytes(text)
  return (
    text:gsub("%s", ""):gsub("%x%x", function(pair)
      return string.char(tonumber(pair, 16))
    end)
  )
end

describe("Zlib", function()
  it("checks for a complete header and validates FCHECK first", function()
    local cases = {
      { "", "FL001", "unexpected end of data", 0 },
      { "78", "FL001", "unexpected end of data", 8 },
      { "79 00", "FL004", "zlib header check failed", 0 },
      { "78 9d", "FL004", "zlib header check failed", 0 },
    }

    for _, case in ipairs(cases) do
      local ok, problem = pcall(Zlib.header, bytes(case[1]))

      assert.is_false(ok, case[1])
      assert.is_true(Problem.is(problem), case[1])
      assert.are.equal(case[2], problem.code, case[1])
      assert.are.equal(case[3], problem.text, case[1])
      assert.are.equal(case[4], problem.pos, case[1])
    end
  end)

  it("validates method, window, and dictionary in order", function()
    local cases = {
      { "79 18", "FL002", "unsupported compression method 9", 0 },
      { "89 33", "FL002", "unsupported compression method 9", 0 },
      { "88 3b", "FL005", "zlib window size too large: CINFO 8", 0 },
      { "88 1c", "FL005", "zlib window size too large: CINFO 8", 0 },
      { "78 20", "FL006", "zlib preset dictionary required", 0 },
    }

    for _, case in ipairs(cases) do
      local ok, problem = pcall(Zlib.header, bytes(case[1]))

      assert.is_false(ok, case[1])
      assert.is_true(Problem.is(problem), case[1])
      assert.are.equal(case[2], problem.code, case[1])
      assert.are.equal(case[3], problem.text, case[1])
      assert.are.equal(case[4], problem.pos, case[1])
    end
  end)

  it("returns the minimum window and every compression level literally", function()
    local cases = {
      { "08 1d", 2, "window: 256 bytes", "level: fastest" },
      { "78 01", 2, "window: 32768 bytes", "level: fastest" },
      { "78 5e", 2, "window: 32768 bytes", "level: fast" },
      { "78 9c", 2, "window: 32768 bytes", "level: default" },
      { "78 da", 2, "window: 32768 bytes", "level: maximum" },
    }

    for _, case in ipairs(cases) do
      local actual = Zlib.header(bytes(case[1]))

      assert.are.same({
        start = case[2],
        lines = { case[3], case[4] },
      }, actual, case[1])
    end
  end)

  it("accepts matching hello and empty trailers and ignores later bytes", function()
    local hello_check, hello_problems = Zlib.trailer(bytes("06 2c 02 15 00 00"), 0, "hello")
    local empty_check, empty_problems = Zlib.trailer(bytes("00 00 00 01"), 0, "")

    assert.are.equal("adler32 ok", hello_check)
    assert.are.same({}, hello_problems)
    assert.are.equal("adler32 ok", empty_check)
    assert.are.same({}, empty_problems)
  end)

  it("returns the exact Adler-32 mismatch at the trailer offset", function()
    local data = bytes("78 9c cb 48 cd c9 c9 07 00 06 2c 02 14")
    local check, problems = Zlib.trailer(data, 9, "hello")

    assert.are.equal("adler32 mismatch", check)
    assert.are.equal(1, #problems)
    assert.is_true(Problem.is(problems[1]))
    assert.are.equal("FL021", problems[1].code)
    assert.are.equal("Adler-32 mismatch: stored 0x062c0214, computed 0x062c0215", problems[1].text)
    assert.are.equal(72, problems[1].pos)
  end)

  it("raises FL001 at the file end for every short trailer", function()
    local cases = {
      { "", 0, 0 },
      { "00", 0, 8 },
      { "00 06", 0, 16 },
      { "00 06 2c", 0, 24 },
      { "00 06 2c 02", 1, 32 },
    }

    for _, case in ipairs(cases) do
      local ok, problem = pcall(Zlib.trailer, bytes(case[1]), case[2], "hello")

      assert.is_false(ok, case[1])
      assert.is_true(Problem.is(problem), case[1])
      assert.are.equal("FL001", problem.code, case[1])
      assert.are.equal("unexpected end of data", problem.text, case[1])
      assert.are.equal(case[3], problem.pos, case[1])
    end
  end)
end)
