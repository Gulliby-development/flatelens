local Cli = require("flatelens.cmd.cli")
local Output = require("flatelens.base.output")

local fixtures = {
  ["hello.hex"] = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 15",
  ["named.hex"] = table.concat({
    "1f 8b 08 1c 00 f1 53 65 00 03 02 00 61 62 ",
    "68 65 6c 6c 6f 2e 74 78 74 00 61 20 22 6e 6f 74 65 22 01 00 ",
    "cb 48 cd c9 c9 57 c8 40 90 5c 00 3b 7c 8a df 12 00 00 00",
  }),
  ["two.hex"] = "00 04 00 fb ff 61 61 61 61 00 00 00 ff ff 4b 4a 82 00 00",
  ["text.hex"] = table.concat({
    "78 da 75 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e 8e d1 ea ab 09 b4 46 4c ",
    "a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 1b 7d 82 ",
    "3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b ",
    "65 04 99 55 59 66 dc 0c 4f 2f f6",
  }),
  ["short.hex"] = "78 9c cb 48",
  ["partial.hex"] = "78 9c 00 01 00 fe ff 78",
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

describe("flatelens.cmd.info_cmd", function()
  it("prints the supplied hello zlib info example", function()
    local stdout, stderr, status = run({ "info", "--hex", "hello.hex" })

    assert.are.equal(
      [=[format: zlib
window: 32768 bytes
level: default
blocks: 1 (1 fixed)
compressed: 7 bytes
uncompressed: 5 bytes
ratio: 140.0%
check: adler32 ok
]=],
      stdout
    )
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)

  it("prints the supplied named gzip info example exactly", function()
    local stdout, stderr, status = run({ "info", "--hex", "named.hex" })

    assert.are.equal(
      "format: gzip\n"
        .. "mtime: 1700000000\n"
        .. "os: unix\n"
        .. 'name: "hello.txt"\n'
        .. 'comment: "a \\"note\\"\\x01"\n'
        .. "extra: 2 bytes\n"
        .. "blocks: 1 (1 fixed)\n"
        .. "compressed: 11 bytes\n"
        .. "uncompressed: 18 bytes\n"
        .. "ratio: 61.1%\n"
        .. "check: crc32 ok, size ok\n",
      stdout
    )
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)

  it("prints the supplied three-block blocks example with original indices", function()
    local stdout, stderr, status = run({ "blocks", "--hex", "two.hex" })

    assert.are.equal(
      "block 1: stored, start 0.0, 72 bits, 4 bytes out, 0 literals, 0 matches\n"
        .. "block 2: stored, start 9.0, 40 bits, 0 bytes out, 0 literals, 0 matches\n"
        .. "block 3: fixed, final, start 14.0, 38 bits, 8 bytes out, 2 literals, 1 match\n",
      stdout
    )
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)

  it("prints the supplied dynamic blocks example", function()
    local stdout, stderr, status = run({ "blocks", "--hex", "text.hex" })

    assert.are.equal(
      [=[block 1: dynamic, final, start 2.0, 584 bits, 138 bytes out, 62 literals, 6 matches
]=],
      stdout
    )
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)

  it("cuts fatal info off after the blocks summary", function()
    local stdout, stderr, status = run({ "info", "--hex", "short.hex" })

    assert.are.equal("format: zlib\nwindow: 32768 bytes\nlevel: default\nblocks: 0\n", stdout)
    assert.are.equal("short.hex: FL001 unexpected end of data at 4.0\n", stderr)
    assert.are.equal(1, status)
  end)

  it("prints no blocks when a fatal stream has no completed block", function()
    local stdout, stderr, status = run({ "blocks", "--hex", "short.hex" })

    assert.are.equal("", stdout)
    assert.are.equal("short.hex: FL001 unexpected end of data at 4.0\n", stderr)
    assert.are.equal(1, status)
  end)

  it("retains completed stored blocks in fatal info and blocks output", function()
    local info, info_err, info_status = run({ "info", "--hex", "partial.hex" })
    local blocks, blocks_err, blocks_status = run({ "blocks", "--hex", "partial.hex" })

    assert.are.equal(
      "format: zlib\n" .. "window: 32768 bytes\n" .. "level: default\n" .. "blocks: 1 (1 stored)\n",
      info
    )
    assert.are.equal("partial.hex: FL001 unexpected end of data at 8.0\n", info_err)
    assert.are.equal(1, info_status)
    assert.are.equal(
      "block 1: stored, start 2.0, 48 bits, 1 byte out, 0 literals, 0 matches\n",
      blocks
    )
    assert.are.equal("partial.hex: FL001 unexpected end of data at 8.0\n", blocks_err)
    assert.are.equal(1, blocks_status)
  end)
end)
