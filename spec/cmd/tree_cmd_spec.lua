local Cli = require("flatelens.cmd.cli")
local Output = require("flatelens.base.output")

local function run(args, files)
  local env = {
    read = function(path)
      return files[path]
    end,
    stdin = function()
      return ""
    end,
  }
  local out = Output.new()
  local status = Cli.run(args, env, out)
  return {
    stdout = out:stdout(),
    stderr = out:stderr(),
    status = status,
  }
end

local hello_hex = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 15"
local short_hex = "78 9c cb 48"
local two_hex = "00 04 00 fb ff 61 61 61 61 00 00 00 ff ff 4b 4a 82 00 00"
local text_hex = table.concat({
  "78 da 75 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e 8e d1 ea ab 09 b4 46 4c ",
  "a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 1b 7d 82 ",
  "3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b ",
  "65 04 99 55 59 66 dc 0c 4f 2f f6",
})

local dynamic_deflate_hex = table.concat({
  "75 cb d1 09 80 30 0c 45 d1 55 de 00 e2 1e 8e d1 ea ab 09 b4 46 4c ",
  "a0 eb 4b bf 44 d0 ef 73 ef 12 e8 c9 11 42 64 7a c0 0a 42 1b 7d 82 ",
  "3e d2 ed fa a3 b4 73 40 57 df ac 7d 49 31 ab ea 72 d0 df 23 4f 5b ",
  "65 04 99 55 59 66 dc",
})
local dynamic_after_stored_hex = "00 00 00 ff ff " .. dynamic_deflate_hex
local dynamic_then_fatal_hex = dynamic_deflate_hex:gsub("^75", "74") .. " 07"
local stored_then_fatal_hex = "00 00 00 ff ff 07"

local text_tree = table.concat({
  "block 1: dynamic, HLIT 271, HDIST 12, HCLEN 18",
  "code length code lengths: 16:0 17:5 18:3 0:2 8:0 7:0 9:0 6:2 "
    .. "10:0 5:3 11:0 4:3 12:0 3:5 13:0 2:5 14:0 1:5",
  "literal/length lengths: 32:3 44:6 46:6 73:6 97-98:5 99-100:6 "
    .. "101:3 102:5 103:6 104-105:4 108-109:5 110:6 111:4 "
    .. "112:6 114:6 115-116:4 119:5 256:6 258:5 264:6 266:6 "
    .. "269-270:6",
  "distance lengths: 9:1 10-11:2",
  "literal/length code: 28 symbols, max length 6, complete",
  "distance code: 3 symbols, max length 2, complete",
  "",
}, "\n")

local mixed_tree = table.concat({
  "block 2: dynamic, HLIT 271, HDIST 12, HCLEN 18",
  "code length code lengths: 16:0 17:5 18:3 0:2 8:0 7:0 9:0 6:2 "
    .. "10:0 5:3 11:0 4:3 12:0 3:5 13:0 2:5 14:0 1:5",
  "literal/length lengths: 32:3 44:6 46:6 73:6 97-98:5 99-100:6 "
    .. "101:3 102:5 103:6 104-105:4 108-109:5 110:6 111:4 "
    .. "112:6 114:6 115-116:4 119:5 256:6 258:5 264:6 266:6 "
    .. "269-270:6",
  "distance lengths: 9:1 10-11:2",
  "literal/length code: 28 symbols, max length 6, complete",
  "distance code: 3 symbols, max length 2, complete",
  "",
}, "\n")

describe("flatelens.cmd.tree", function()
  it("renders every dynamic block and selects it by its original index", function()
    assert.are.same({
      stdout = text_tree,
      stderr = "",
      status = 0,
    }, run({ "tree", "--hex", "text.hex" }, { ["text.hex"] = text_hex }))

    assert.are.same({
      stdout = text_tree,
      stderr = "",
      status = 0,
    }, run({ "tree", "--hex", "--block", "1", "text.hex" }, { ["text.hex"] = text_hex }))
  end)

  it("prints no-dynamic and missing-block results with singular and plural counts", function()
    assert.are.same({
      stdout = "no dynamic blocks\n",
      stderr = "",
      status = 0,
    }, run({ "tree", "--hex", "hello.hex" }, { ["hello.hex"] = hello_hex }))

    assert.are.same({
      stdout = "",
      stderr = "flatelens: no block 2 (the stream has 1 block)\n",
      status = 2,
    }, run({ "tree", "--hex", "--block", "2", "text.hex" }, { ["text.hex"] = text_hex }))

    assert.are.same({
      stdout = "",
      stderr = "flatelens: no block 3 (the stream has 1 block)\n",
      status = 2,
    }, run({ "tree", "--hex", "--block", "3", "hello.hex" }, { ["hello.hex"] = hello_hex }))

    assert.are.same({
      stdout = "",
      stderr = "flatelens: no block 4 (the stream has 3 blocks)\n",
      status = 2,
    }, run({ "tree", "--hex", "--block", "4", "two.hex" }, { ["two.hex"] = two_hex }))
  end)

  it("retains original indices when a dynamic block follows a stored block", function()
    assert.are.same({
      stdout = mixed_tree,
      stderr = "",
      status = 0,
    }, run({ "tree", "--hex", "mixed.hex" }, { ["mixed.hex"] = dynamic_after_stored_hex }))

    assert.are.same(
      {
        stdout = mixed_tree,
        stderr = "",
        status = 0,
      },
      run(
        { "tree", "--hex", "--block", "2", "mixed.hex" },
        { ["mixed.hex"] = dynamic_after_stored_hex }
      )
    )
  end)

  it("retains completed dynamic blocks before a later fatal block", function()
    assert.are.same({
      stdout = text_tree,
      stderr = "fatal.hex: FL010 reserved block type 3 at 73.0\n",
      status = 1,
    }, run({ "tree", "--hex", "fatal.hex" }, { ["fatal.hex"] = dynamic_then_fatal_hex }))

    assert.are.same(
      {
        stdout = text_tree,
        stderr = "fatal.hex: FL010 reserved block type 3 at 73.0\n",
        status = 1,
      },
      run(
        { "tree", "--hex", "--block", "1", "fatal.hex" },
        { ["fatal.hex"] = dynamic_then_fatal_hex }
      )
    )

    assert.are.same(
      {
        stdout = "",
        stderr = "fatal.hex: FL010 reserved block type 3 at 73.0\n",
        status = 1,
      },
      run(
        { "tree", "--hex", "--block", "2", "fatal.hex" },
        { ["fatal.hex"] = dynamic_then_fatal_hex }
      )
    )
  end)

  it("reports selected stored and fixed blocks as command-line errors", function()
    assert.are.same({
      stdout = "",
      stderr = "flatelens: block 1 is stored, not dynamic\n",
      status = 2,
    }, run({ "tree", "--hex", "--block", "1", "two.hex" }, { ["two.hex"] = two_hex }))

    assert.are.same({
      stdout = "",
      stderr = "flatelens: block 3 is fixed, not dynamic\n",
      status = 2,
    }, run({ "tree", "--hex", "--block", "3", "two.hex" }, { ["two.hex"] = two_hex }))
  end)

  it("gives a completed non-dynamic selection precedence over a later fatal block", function()
    assert.are.same(
      {
        stdout = "",
        stderr = "flatelens: block 1 is stored, not dynamic\n",
        status = 2,
      },
      run(
        { "tree", "--hex", "--block", "1", "fatal-stored.hex" },
        { ["fatal-stored.hex"] = stored_then_fatal_hex }
      )
    )
  end)

  it("prints only fatal diagnostics when the stream stops before a selection", function()
    assert.are.same({
      stdout = "",
      stderr = "short.hex: FL001 unexpected end of data at 4.0\n",
      status = 1,
    }, run({ "tree", "--hex", "short.hex" }, { ["short.hex"] = short_hex }))

    assert.are.same({
      stdout = "",
      stderr = "short.hex: FL001 unexpected end of data at 4.0\n",
      status = 1,
    }, run({ "tree", "--hex", "--block", "2", "short.hex" }, { ["short.hex"] = short_hex }))
  end)
end)
