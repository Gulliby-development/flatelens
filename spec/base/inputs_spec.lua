local Failure = require("flatelens.base.failure")
local Inputs = require("flatelens.base.inputs")

local function failure_of(callback)
  local ok, value = pcall(callback)
  assert.is_false(ok)
  assert.is_true(Failure.is(value))
  return value
end

describe("flatelens.base.inputs", function()
  it("displays stdin and preserves file names", function()
    assert.are.equal("<stdin>", Inputs.display_name("-"))
    assert.are.equal("a.bin", Inputs.display_name("a.bin"))
  end)

  it("loads raw file bytes and records the requested path", function()
    local bytes = string.char(0, 13, 10, 26, 0xff)
    local read_path
    local stdin_calls = 0
    local env = {
      read = function(path)
        read_path = path
        return bytes
      end,
      stdin = function()
        stdin_calls = stdin_calls + 1
        return "unused"
      end,
    }

    assert.are.equal(bytes, Inputs.load("a.bin", false, env))
    assert.are.equal("a.bin", read_path)
    assert.are.equal(0, stdin_calls)
  end)

  it("reports unreadable files and forbids stdin without invoking readers", function()
    local read_calls = 0
    local stdin_calls = 0
    local env = {
      read = function(_path)
        read_calls = read_calls + 1
        return nil
      end,
      stdin = function()
        stdin_calls = stdin_calls + 1
        return "41"
      end,
    }

    local unreadable = failure_of(function()
      Inputs.load("gone", false, env)
    end)
    assert.are.equal(2, unreadable.exit_code)
    assert.are.equal("flatelens: gone: cannot read file", unreadable.message)
    assert.are.equal(1, read_calls)
    assert.are.equal(0, stdin_calls)

    local forbidden = failure_of(function()
      Inputs.load("-", false, env)
    end)
    assert.are.equal(2, forbidden.exit_code)
    assert.are.equal("flatelens: standard input needs --hex", forbidden.message)
    assert.are.equal(1, read_calls)
    assert.are.equal(0, stdin_calls)
  end)

  it("loads hex from stdin or a file using only the matching reader", function()
    local read_calls = {}
    local stdin_calls = 0
    local env = {
      read = function(path)
        read_calls[#read_calls + 1] = path
        return "41 42"
      end,
      stdin = function()
        stdin_calls = stdin_calls + 1
        return "41\r\n42"
      end,
    }

    assert.are.equal("AB", Inputs.load("-", true, env))
    assert.are.equal(1, stdin_calls)
    assert.are.equal(0, #read_calls)

    assert.are.equal("AB", Inputs.load("a.hex", true, env))
    assert.are.equal(1, stdin_calls)
    assert.are.same({ "a.hex" }, read_calls)
  end)

  it("decodes ASCII hex digits across separators and line endings", function()
    assert.are.equal("", Inputs.decode_hex("", "x.hex"))
    assert.are.equal(string.char(0x41, 0x42, 0xAF), Inputs.decode_hex("4 \t1\r\n4\n2aF", "x.hex"))
    assert.are.equal(string.char(0xff), Inputs.decode_hex("ff", "x.hex"))
  end)

  it("validates all UTF-8 before reporting hex characters", function()
    local failure = failure_of(function()
      Inputs.decode_hex("g" .. string.char(255), "x.hex")
    end)

    assert.are.equal(2, failure.exit_code)
    assert.are.equal("flatelens: x.hex: not valid UTF-8 text", failure.message)
  end)

  it("reports invalid characters with code-point positions", function()
    local rows = {
      {
        "00 00 g",
        "flatelens: x.hex: invalid hex character 'g' at line 1 column 7",
      },
      {
        "41\n \té",
        "flatelens: x.hex: invalid hex character U+00E9 at line 2 column 3",
      },
      {
        "\v",
        "flatelens: x.hex: invalid hex character U+000B at line 1 column 1",
      },
      {
        "😀",
        "flatelens: x.hex: invalid hex character U+1F600 at line 1 column 1",
      },
      {
        "ag",
        "flatelens: x.hex: invalid hex character 'g' at line 1 column 2",
      },
    }

    for _, row in ipairs(rows) do
      local failure = failure_of(function()
        Inputs.decode_hex(row[1], "x.hex")
      end)
      assert.are.equal(2, failure.exit_code)
      assert.are.equal(row[2], failure.message)
    end
  end)

  it("reports an odd digit only after all characters are validated", function()
    local failure = failure_of(function()
      Inputs.decode_hex("a", "x.hex")
    end)

    assert.are.equal(2, failure.exit_code)
    assert.are.equal("flatelens: x.hex: odd number of hex digits", failure.message)
  end)

  it("names invalid UTF-8 on hex stdin as stdin", function()
    local stdin_calls = 0
    local failure = failure_of(function()
      Inputs.load("-", true, {
        read = function(_path)
          return "unused"
        end,
        stdin = function()
          stdin_calls = stdin_calls + 1
          return string.char(255)
        end,
      })
    end)

    assert.are.equal(2, failure.exit_code)
    assert.are.equal("flatelens: <stdin>: not valid UTF-8 text", failure.message)
    assert.are.equal(1, stdin_calls)
  end)

  it("round-trips binary bytes through a temporary file", function()
    local path = os.tmpname()
    local bytes = string.char(0, 13, 10, 26, 0xff)
    local ok, err = pcall(function()
      local handle = assert(io.open(path, "wb"))
      local write_ok, write_err = pcall(function()
        assert(handle:write(bytes))
      end)
      handle:close()
      if not write_ok then
        error(write_err, 0)
      end

      local env = {
        read = function(read_path)
          local input = io.open(read_path, "rb")
          if input == nil then
            return nil
          end
          local data = input:read("a")
          input:close()
          return data
        end,
        stdin = function()
          return ""
        end,
      }

      assert.are.equal(bytes, Inputs.load(path, false, env))
    end)
    os.remove(path)
    if not ok then
      error(err, 0)
    end
  end)
end)
