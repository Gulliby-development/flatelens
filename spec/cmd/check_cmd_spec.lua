local Cli = require("flatelens.cmd.cli")
local Output = require("flatelens.base.output")

local function bytes(text)
  return (
    text:gsub("%s", ""):gsub("%x%x", function(pair)
      return string.char(tonumber(pair, 16))
    end)
  )
end

local function hex_text(data)
  return (data:gsub(".", function(char)
    return string.format("%02x ", string.byte(char))
  end))
end

local hello_hex = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 15"
local hello_bad_checksum_hex = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 14"
local hello_short_hex = "78 9c cb 48"

local named_gzip_hex = table.concat({
  "1f 8b 08 1c 00 f1 53 65 00 03 02 00 61 62 ",
  "68 65 6c 6c 6f 2e 74 78 74 00 61 20 22 6e 6f 74 65 22 01 00 ",
  "cb 48 cd c9 c9 57 c8 40 90 5c 00 3b 7c 8a df 12 00 00 00",
})
local named_gzip = bytes(named_gzip_hex)

local function run(args, files)
  local out = Output.new()
  local env = {
    read = function(path)
      return files[path]
    end,
    stdin = function()
      return ""
    end,
  }
  local status = Cli.run(args, env, out)
  return out:stdout(), out:stderr(), status
end

describe("check command", function()
  it("continues after read and hex failures and counts only loaded files and problems", function()
    local cases = {
      {
        { "check", "--hex", "hello.hex", "bad.hex", "short.hex", "gone.hex" },
        {
          ["hello.hex"] = hello_hex,
          ["bad.hex"] = hello_bad_checksum_hex,
          ["short.hex"] = hello_short_hex,
        },
        [[hello.hex: ok
bad.hex: FL021 Adler-32 mismatch: stored 0x062c0214, computed 0x062c0215 at 9.0
short.hex: FL001 unexpected end of data at 4.0
checked 3 files, 2 problems
]],
        "flatelens: gone.hex: cannot read file\n",
        2,
      },
      {
        { "check", "--hex", "gone.hex", "hello.hex" },
        { ["hello.hex"] = hello_hex },
        [[hello.hex: ok
checked 1 file, 0 problems
]],
        "flatelens: gone.hex: cannot read file\n",
        2,
      },
      {
        { "check", "--hex", "odd.hex", "hello.hex" },
        { ["odd.hex"] = "0", ["hello.hex"] = hello_hex },
        [[hello.hex: ok
checked 1 file, 0 problems
]],
        [[flatelens: odd.hex: odd number of hex digits
]],
        2,
      },
      {
        { "check", "--hex", "gone.hex" },
        {},
        [[checked 0 files, 0 problems
]],
        "flatelens: gone.hex: cannot read file\n",
        2,
      },
      {
        { "check", "--hex", "hello.hex" },
        { ["hello.hex"] = hello_hex },
        [[hello.hex: ok
checked 1 file, 0 problems
]],
        "",
        0,
      },
      {
        { "check", "--hex", "bad.hex" },
        { ["bad.hex"] = hello_bad_checksum_hex },
        [[bad.hex: FL021 Adler-32 mismatch: stored 0x062c0214, computed 0x062c0215 at 9.0
checked 1 file, 1 problem
]],
        "",
        1,
      },
    }

    for _, case in ipairs(cases) do
      local stdout, stderr, status = run(case[1], case[2])
      assert.are.equal(case[3], stdout)
      assert.are.equal(case[4], stderr)
      assert.are.equal(case[5], status)
    end
  end)

  it("reports every specified stream problem with its exact text and position", function()
    local cases = {
      {
        "auto",
        "78 9c cb 48",
        "x.hex: FL001 unexpected end of data at 4.0\nchecked 1 file, 1 problem\n",
      },
      {
        "auto",
        "1f 8b 07 " .. string.rep("00 ", 6) .. "03",
        "x.hex: FL002 unsupported compression method 7 at 0.0\n" .. "checked 1 file, 1 problem\n",
      },
      {
        "auto",
        "1f 8b 08 20 " .. string.rep("00 ", 5) .. "03",
        "x.hex: FL003 reserved gzip flag bits set: 0x20 at 0.0\n" .. "checked 1 file, 1 problem\n",
      },
      {
        "zlib",
        "78 9d cb 48 cd c9 c9 07 00 06 2c 02 15",
        "x.hex: FL004 zlib header check failed at 0.0\nchecked 1 file, 1 problem\n",
      },
      {
        "auto",
        "88 1c cb 48 cd c9 c9 07 00 06 2c 02 15",
        "x.hex: FL005 zlib window size too large: CINFO 8 at 0.0\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "auto",
        "78 20 01 02 03 04 cb 48 cd c9 c9 07 00 06 2c 02 15",
        "x.hex: FL006 zlib preset dictionary required at 0.0\n" .. "checked 1 file, 1 problem\n",
      },
      {
        "auto",
        "1f 8b 08 02 " .. string.rep("00 ", 5) .. "03 a6 77 03 " .. string.rep("00 ", 9),
        "x.hex: FL007 gzip header CRC mismatch: stored 0x77a6, computed 0x77a7 at 0.0\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "gzip",
        "78 9c cb 48 cd c9 c9 07 00 06 2c 02 15",
        "x.hex: FL008 not a gzip stream at 0.0\nchecked 1 file, 1 problem\n",
      },
      {
        "raw",
        "07",
        "x.hex: FL010 reserved block type 3 at 0.0\nchecked 1 file, 1 problem\n",
      },
      {
        "raw",
        "01 03 00 fc fe 61 62 63",
        "x.hex: FL011 stored block length check failed: LEN 3, NLEN 65276 at 0.0\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "raw",
        "f5 00 00 00",
        "x.hex: FL012 too many length or distance symbols: HLIT 287, HDIST 1 at 0.0\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "raw",
        "05 00 92 00",
        "x.hex: FL013 code length code is over-subscribed at 0.0\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "raw",
        "05 00 02 24",
        "x.hex: FL014 invalid code length repeat at 0.0\nchecked 1 file, 1 problem\n",
      },
      {
        "raw",
        "05 c0 01 04 " .. string.rep("00 ", 4) .. "10 " .. string.rep("00 ", 33),
        "x.hex: FL015 no end-of-block code (symbol 256 has length 0) at 0.0\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "raw",
        "05 c0 01 04 " .. string.rep("00 ", 4) .. "90 03 " .. string.rep("00 ", 30) .. "80 00",
        "x.hex: FL016 literal/length code is over-subscribed at 0.0\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "raw",
        "05 80 01 04 00 00 00 40 " .. string.rep("00 ", 32) .. "02",
        "x.hex: FL016 literal/length code is incomplete at 0.0\n" .. "checked 1 file, 1 problem\n",
      },
      {
        "raw",
        "05 c2 01 04 " .. string.rep("00 ", 4) .. "90 " .. string.rep("00 ", 31) .. "80 07",
        "x.hex: FL017 distance code is over-subscribed at 0.0\nchecked 1 file, 1 problem\n",
      },
      {
        "raw",
        "1b 03",
        "x.hex: FL018 invalid literal/length code at 0.3\nchecked 1 file, 1 problem\n",
      },
      {
        "raw",
        "03 3e",
        "x.hex: FL019 invalid distance code at 1.2\nchecked 1 file, 1 problem\n",
      },
      {
        "raw",
        "03 02 00",
        "x.hex: FL020 distance 1 is more than the 0 bytes written so far at 1.2\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "auto",
        "78 9c cb 48 cd c9 c9 07 00 06 2c 02 14",
        "x.hex: FL021 Adler-32 mismatch: stored 0x062c0214, computed 0x062c0215 at 9.0\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "auto",
        hex_text(named_gzip:sub(1, #named_gzip - 4) .. bytes("13 00 00 00")),
        "x.hex: FL022 size mismatch: stored 19, computed 18 at 45.0\n"
          .. "checked 1 file, 1 problem\n",
      },
      {
        "auto",
        hello_hex .. " 00 00",
        "x.hex: FL023 2 bytes after the end of the stream at 13.0\n"
          .. "checked 1 file, 1 problem\n",
      },
    }

    for _, case in ipairs(cases) do
      local args = { "check", "--hex" }
      if case[1] ~= "auto" then
        args[#args + 1] = "--format"
        args[#args + 1] = case[1]
      end
      args[#args + 1] = "x.hex"

      local stdout, stderr, status = run(args, { ["x.hex"] = case[2] })
      assert.are.equal(case[3], stdout, case[3])
      assert.are.equal("", stderr, case[3])
      assert.are.equal(1, status, case[3])
    end
  end)

  it("counts and orders CRC, size, and trailing problems individually", function()
    local invalid_trailer = named_gzip:sub(1, 45) .. bytes("01 00 00 00 02 00 00 00")
    local invalid_with_trailing = invalid_trailer .. bytes("aa bb")
    local cases = {
      {
        invalid_trailer,
        "x.hex: FL021 CRC-32 mismatch: stored 0x00000001, computed 0xdf8a7c3b at 45.0\n"
          .. "x.hex: FL022 size mismatch: stored 2, computed 18 at 45.0\n"
          .. "checked 1 file, 2 problems\n",
      },
      {
        invalid_with_trailing,
        "x.hex: FL021 CRC-32 mismatch: stored 0x00000001, computed 0xdf8a7c3b at 45.0\n"
          .. "x.hex: FL022 size mismatch: stored 2, computed 18 at 45.0\n"
          .. "x.hex: FL023 2 bytes after the end of the stream at 53.0\n"
          .. "checked 1 file, 3 problems\n",
      },
    }

    for _, case in ipairs(cases) do
      local stdout, stderr, status = run(
        { "check", "--hex", "x.hex" },
        { ["x.hex"] = hex_text(case[1]) }
      )
      assert.are.equal(case[2], stdout)
      assert.are.equal("", stderr)
      assert.are.equal(1, status)
    end
  end)

  it("rethrows an unrelated read exception by identity", function()
    local sentinel = { reason = "read sentinel" }
    local out = Output.new()
    local ok, err = pcall(Cli.run, { "check", "broken.bin" }, {
      read = function(_path)
        error(sentinel, 0)
      end,
      stdin = function()
        return ""
      end,
    }, out)

    assert.is_false(ok)
    assert.is_true(rawequal(sentinel, err))
    assert.are.equal("", out:stdout())
    assert.are.equal("", out:stderr())
  end)
end)
