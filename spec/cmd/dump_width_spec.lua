local Cli = require("flatelens.cmd.cli")
local Output = require("flatelens.base.output")

local fixtures = {
  ["hello.hex"] = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 15",
  ["bad.hex"] = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 14",
  ["short.hex"] = "78 9c cb 48",
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

local function check(cases)
  for _, case in ipairs(cases) do
    local label = table.concat(case.args, " ")
    local stdout, stderr, status = run(case.args)
    assert.are.equal(case.stdout, stdout, label)
    assert.are.equal(case.stderr, stderr, label)
    assert.are.equal(case.status, status, label)
  end
end

describe("flatelens dump --width", function()
  it("prints rows of the requested width", function()
    check({
      {
        args = { "dump", "--hex", "--width", "2", "hello.hex" },
        stdout = table.concat({
          "00000000  68 65  |he|",
          "00000002  6c 6c  |ll|",
          "00000004  6f     |o|",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--width", "5", "hello.hex" },
        stdout = table.concat({
          "00000000  68 65 6c 6c 6f  |hello|",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--width", "1", "--limit", "2", "hello.hex" },
        stdout = table.concat({
          "00000000  68  |h|",
          "00000001  65  |e|",
          "... 3 bytes more",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--width=3", "--skip", "1", "hello.hex" },
        stdout = table.concat({
          "00000001  65 6c 6c  |ell|",
          "00000004  6f        |o|",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "hello.hex", "--width", "4" },
        stdout = table.concat({
          "00000000  68 65 6c 6c  |hell|",
          "00000004  6f           |o|",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--width", "3", "--width", "6", "hello.hex" },
        stdout = table.concat({
          "00000000  68 65 6c 6c 6f     |hello|",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--width", "007", "hello.hex" },
        stdout = table.concat({
          "00000000  68 65 6c 6c 6f        |hello|",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--width", "16", "hello.hex" },
        stdout = table.concat({
          "00000000  68 65 6c 6c 6f                                   |" .. "hello|",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--format", "raw", "--width", "32", "--limit", "40", "long.raw" },
        stdout = table.concat({
          "00000000  41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41"
            .. " 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41  |AAAAAAAAAAAA"
            .. "AAAAAAAAAAAAAAAAAAAA|",
          "00000020  41 41 41 41 41 41 41 41                           "
            .. "                                               |AAAAAAAA|",
          "... 220 bytes more",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--skip", "4", "--limit", "20", "--width", "8", "text.hex" },
        stdout = table.concat({
          "00000004  61 73 20 74 68 65 20 62  |as the b|",
          "0000000c  65 73 74 20 6f 66 20 74  |est of t|",
          "00000014  69 6d 65 73              |imes|",
          "... 114 bytes more",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--format", "raw", "--width", "3", "ascii.raw" },
        stdout = table.concat({
          "00000000  1f 20 7e  |. ~|",
          "00000003  7f        |.|",
        }, "\n") .. "\n",
        stderr = "",
        status = 0,
      },
      {
        args = { "dump", "--hex", "--width", "2", "bad.hex" },
        stdout = table.concat({
          "00000000  68 65  |he|",
          "00000002  6c 6c  |ll|",
          "00000004  6f     |o|",
        }, "\n") .. "\n",
        stderr = "bad.hex: FL021 Adler-32 mismatch: stored 0x062c0214, compute"
          .. "d 0x062c0215 at 9.0\n",
        status = 1,
      },
      {
        args = { "dump", "--hex", "--width", "2", "short.hex" },
        stdout = "",
        stderr = "short.hex: FL001 unexpected end of data at 4.0\n",
        status = 1,
      },
    })
  end)

  it("rejects a width outside 1 to 64 and unknown uses of the option", function()
    check({
      {
        args = { "dump", "--hex", "--width", "0", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value: 0\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "65", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value: 65\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "100", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value: 100\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "abc", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value: abc\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "-1", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value: -1\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "1.5", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value: 1.5\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "", "hello.hex" },
        stdout = "",
        stderr = "flatelens: option --width needs a non-empty value\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", " 8", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value:  8\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "1000000000", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value: 1000000000\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "\u{661}", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value: \u{661}\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "hello.hex", "--width" },
        stdout = "",
        stderr = "flatelens: option --width needs a value\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width=", "hello.hex" },
        stdout = "",
        stderr = "flatelens: option --width needs a non-empty value\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "0", "missing.hex" },
        stdout = "",
        stderr = "flatelens: invalid --width value: 0\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--limit", "0", "--width", "65", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --limit value: 0\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--skip", "x", "--width", "0", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --skip value: x\n",
        status = 2,
      },
      {
        args = { "dump", "--hex", "--width", "0", "--format", "gz", "hello.hex" },
        stdout = "",
        stderr = "flatelens: invalid --format value: gz\n",
        status = 2,
      },
      {
        args = { "info", "--hex", "--width", "8", "hello.hex" },
        stdout = "",
        stderr = "flatelens: unknown option --width\n",
        status = 2,
      },
      {
        args = { "blocks", "--hex", "--width", "8", "hello.hex" },
        stdout = "",
        stderr = "flatelens: unknown option --width\n",
        status = 2,
      },
      {
        args = { "tree", "--hex", "--width", "8", "hello.hex" },
        stdout = "",
        stderr = "flatelens: unknown option --width\n",
        status = 2,
      },
      {
        args = { "check", "--hex", "--width", "8", "hello.hex" },
        stdout = "",
        stderr = "flatelens: unknown option --width\n",
        status = 2,
      },
      {
        args = { "codes", "--width", "8", "1", "1" },
        stdout = "",
        stderr = "flatelens: unknown option --width\n",
        status = 2,
      },
    })
  end)
end)
