local Hexdump = require("flatelens.render.hexdump")

describe("Hexdump.render", function()
  it("returns no lines for empty or exhausted selections", function()
    local cases = {
      { bytes = "", skip = 0, limit = 256, expected = {} },
      { bytes = "abc", skip = 3, limit = 16, expected = {} },
      { bytes = "abc", skip = 4, limit = 16, expected = {} },
    }

    for _, case in ipairs(cases) do
      assert.are.same(case.expected, Hexdump.render(case.bytes, case.skip, case.limit))
    end
  end)

  it("reports unrendered bytes when the limit is zero", function()
    assert.are.same({ "... 3 bytes more" }, Hexdump.render("abc", 0, 0))
  end)

  it("renders full rows with singular and plural remainder counts", function()
    local cases = {
      {
        bytes = "0123456789abcdefX",
        skip = 0,
        limit = 16,
        expected = {
          "00000000  30 31 32 33 34 35 36 37 38 39 61 62 63 64 65 66  |0123456789abcdef|",
          "... 1 byte more",
        },
      },
      {
        bytes = "0123456789abcdefXYZ",
        skip = 1,
        limit = 16,
        expected = {
          "00000001  31 32 33 34 35 36 37 38 39 61 62 63 64 65 66 58  |123456789abcdefX|",
          "... 2 bytes more",
        },
      },
    }

    for _, case in ipairs(cases) do
      assert.are.same(case.expected, Hexdump.render(case.bytes, case.skip, case.limit))
    end
  end)

  it("renders partial rows at the limit and omits a suffix on exact exhaustion", function()
    local cases = {
      {
        bytes = "0123456789abcdefXYZ",
        skip = 0,
        limit = 17,
        expected = {
          "00000000  30 31 32 33 34 35 36 37 38 39 61 62 63 64 65 66  |0123456789abcdef|",
          "00000010  58                                               |X|",
          "... 2 bytes more",
        },
      },
      {
        bytes = "0123456789abcdef",
        skip = 0,
        limit = 16,
        expected = {
          "00000000  30 31 32 33 34 35 36 37 38 39 61 62 63 64 65 66  |0123456789abcdef|",
        },
      },
    }

    for _, case in ipairs(cases) do
      assert.are.same(case.expected, Hexdump.render(case.bytes, case.skip, case.limit))
    end
  end)

  it("renders multiple rows and an exact partial final row", function()
    assert.are.same({
      "00000000  30 31 32 33 34 35 36 37 38 39 61 62 63 64 65 66  |0123456789abcdef|",
      "00000010  58                                               |X|",
    }, Hexdump.render("0123456789abcdefX", 0, 32))
  end)

  it("renders only printable ASCII literally", function()
    assert.are.same({
      "00000000  00 1f 20 7e 7f ff                                |.. ~..|",
    }, Hexdump.render(string.char(0, 31, 32, 126, 127, 255), 0, 16))
  end)

  it("returns fresh stable lines and leaves its inputs unchanged", function()
    local bytes = "0123456789abcdefX"
    local skip = 0
    local limit = 16
    local expected = {
      "00000000  30 31 32 33 34 35 36 37 38 39 61 62 63 64 65 66  |0123456789abcdef|",
      "... 1 byte more",
    }
    local first = Hexdump.render(bytes, skip, limit)
    local second = Hexdump.render(bytes, skip, limit)

    assert.are.same(expected, first)
    assert.are.same(first, second)
    assert.is_true(first ~= second)
    for _, line in ipairs(first) do
      assert.is_nil(line:find("\n", 1, true))
    end

    first[1] = "changed"
    assert.are.same(expected, Hexdump.render(bytes, skip, limit))
    assert.are.equal("0123456789abcdefX", bytes)
    assert.are.equal(0, skip)
    assert.are.equal(16, limit)
  end)

  it("does not perform input or output I/O", function()
    local old_io = io
    local old_print = _G.print
    local function reject_io()
      error("unexpected I/O")
    end

    rawset(
      _G,
      "io",
      setmetatable({}, {
        __index = function()
          return reject_io
        end,
      })
    )
    _G.print = reject_io
    local ok, result = pcall(Hexdump.render, "0123456789abcdef", 0, 16)
    rawset(_G, "io", old_io)
    _G.print = old_print

    assert.is_true(ok, tostring(result))
    assert.are.same({
      "00000000  30 31 32 33 34 35 36 37 38 39 61 62 63 64 65 66  |0123456789abcdef|",
    }, result)
  end)
end)
