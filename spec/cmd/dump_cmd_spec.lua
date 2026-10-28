local Cli = require("flatelens.cmd.cli")
local Output = require("flatelens.base.output")

local fixtures = {
  ["hello.hex"] = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 15",
  ["bad.hex"] = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 14",
  ["short.hex"] = "78 9c cb 48",
  ["partial.hex"] = "78 9c 00 01 00 fe ff 78",
  ["text.hex"] = table.concat({
    "78 da 75 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e 8e d1 ea ab 09 b4 46 4c ",
    "a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 1b 7d 82 ",
    "3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b ",
    "65 04 99 55 59 66 dc 0c 4f 2f f6",
  }),
  ["long.raw"] = string.char(1, 4, 1, 251, 254) .. string.rep("A", 260),
  ["ascii.raw"] = string.char(1, 4, 0, 251, 255, 0x1f, 0x20, 0x7e, 0x7f),
}

local function run(args)
  local out = Output.new()
  local env = {
    read = function(path)
      return fixtures[path]
    end,
    stdin = function()
      return ""
    end,
  }

  local status = Cli.run(args, env, out)
  return out:stdout(), out:stderr(), status
end

local short_padding = "\x20\x20\x20\x20\x20\x20\x20\x20\x20"
  .. "\x20\x20\x20\x20\x20\x20\x20\x20\x20"
  .. "\x20\x20\x20\x20\x20\x20\x20\x20\x20"
  .. "\x20\x20\x20\x20\x20\x20\x20\x20\x20"
local hello_padding = "\x20\x20\x20\x20\x20\x20\x20\x20\x20"
  .. "\x20\x20\x20\x20\x20\x20\x20\x20\x20"
  .. "\x20\x20\x20\x20\x20\x20\x20\x20\x20"
  .. "\x20\x20\x20\x20\x20\x20"

describe("flatelens.cmd.dump_cmd", function()
  it("prints the supplied clipped text dump example exactly", function()
    local stdout, stderr, status =
      run({ "dump", "--hex", "--skip", "4", "--limit", "40", "text.hex" })

    assert.are.equal(
      [=[00000004  61 73 20 74 68 65 20 62 65 73 74 20 6f 66 20 74  |as the best of t|
00000014  69 6d 65 73 2c 20 69 74 20 77 61 73 20 74 68 65  |imes, it was the|
00000024  20 77 6f 72 73 74 20 6f                          | worst o|
... 94 bytes more
]=],
      stdout
    )
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)

  it("handles skips at and beyond the end and a singular limited suffix", function()
    local padded_hello = "00000000  68 65 6c 6c" .. short_padding .. "  |hell|\n... 1 byte more\n"
    local cases = {
      {
        args = { "dump", "--hex", "--skip", "5", "hello.hex" },
        stdout = "",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--skip", "6", "hello.hex" },
        stdout = "",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--limit", "4", "hello.hex" },
        stdout = padded_hello,
        stderr = "",
        status = 0,
      },
    }

    for _, case in ipairs(cases) do
      local stdout, stderr, status = run(case.args)
      assert.are.equal(case.stdout, stdout, table.concat(case.args, " "))
      assert.are.equal(case.stderr, stderr, table.concat(case.args, " "))
      assert.are.equal(case.status, status, table.concat(case.args, " "))
    end
  end)

  it("uses the default 256-byte limit and matches its explicit boundary", function()
    local full_limit_output =
      [=[00000000  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
00000010  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
00000020  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
00000030  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
00000040  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
00000050  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
00000060  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
00000070  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
00000080  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
00000090  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
000000a0  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
000000b0  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
000000c0  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
000000d0  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
000000e0  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
000000f0  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAAAAAA|
... 4 bytes more
]=]
    local stdout, stderr, status = run({ "dump", "--format", "raw", "long.raw" })

    assert.are.equal(full_limit_output, stdout)
    assert.are.equal("", stderr)
    assert.are.equal(0, status)

    local explicit_stdout, explicit_stderr, explicit_status =
      run({ "dump", "--format", "raw", "--skip", "0", "--limit", "256", "long.raw" })
    assert.are.equal(full_limit_output, explicit_stdout)
    assert.are.equal("", explicit_stderr)
    assert.are.equal(0, explicit_status)
  end)

  it("renders printable endpoints and substitutes adjacent non-printable bytes", function()
    local stdout, stderr, status = run({ "dump", "--format", "raw", "ascii.raw" })

    assert.are.equal("00000000  1f 20 7e 7f" .. short_padding .. "  |. ~.|\n", stdout)
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)

  it("suppresses empty and partial output when decoding stops fatally", function()
    local cases = {
      {
        args = { "dump", "--hex", "short.hex" },
        stderr = "short.hex: FL001 unexpected end of data at 4.0\n",
      },
      {
        args = { "dump", "--hex", "partial.hex" },
        stderr = "partial.hex: FL001 unexpected end of data at 8.0\n",
      },
    }

    for _, case in ipairs(cases) do
      local stdout, stderr, status = run(case.args)
      assert.are.equal("", stdout, table.concat(case.args, " "))
      assert.are.equal(case.stderr, stderr, table.concat(case.args, " "))
      assert.are.equal(1, status, table.concat(case.args, " "))
    end
  end)

  it("retains the fatal info summary when the stream is truncated", function()
    local stdout, stderr, status = run({ "info", "--hex", "short.hex" })

    assert.are.equal("format: zlib\nwindow: 32768 bytes\nlevel: default\nblocks: 0\n", stdout)
    assert.are.equal("short.hex: FL001 unexpected end of data at 4.0\n", stderr)
    assert.are.equal(1, status)
  end)

  it("keeps the decoded dump when the stream has a nonfatal checksum problem", function()
    local stdout, stderr, status = run({ "dump", "--hex", "bad.hex" })

    assert.are.equal("00000000  68 65 6c 6c 6f" .. hello_padding .. "  |hello|\n", stdout)
    assert.are.equal(
      "bad.hex: FL021 Adler-32 mismatch: stored 0x062c0214, computed 0x062c0215 at 9.0\n",
      stderr
    )
    assert.are.equal(1, status)
  end)
end)
