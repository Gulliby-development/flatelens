local Block = require("flatelens.model.block")
local Blocks = require("flatelens.render.blocks")

describe("flatelens.render.blocks", function()
  it("returns no lines for an empty block list", function()
    assert.are.same({}, Blocks.render({}))
  end)

  it("renders Block defaults and fields that override them", function()
    local default_block = Block.new({
      kind = "stored",
      start = 0,
      stop = 0,
    })
    local overridden_block = Block.new({
      kind = "fixed",
      start = 8,
      stop = 9,
      out = 1,
      lit = 1,
      match = 1,
      final = true,
    })

    assert.are.same({
      "block 1: stored, start 0.0, 0 bits, 0 bytes out, 0 literals, 0 matches",
    }, Blocks.render({ default_block }))
    assert.are.same({
      "block 1: fixed, final, start 1.0, 1 bit, 1 byte out, 1 literal, 1 match",
    }, Blocks.render({ overridden_block }))
  end)

  it("renders the stored, stored, fixed fixture with original indices", function()
    local blocks = {
      {
        kind = "stored",
        start = 0,
        stop = 72,
        out = 4,
        lit = 0,
        match = 0,
        final = false,
      },
      {
        kind = "stored",
        start = 72,
        stop = 112,
        out = 0,
        lit = 0,
        match = 0,
        final = false,
      },
      {
        kind = "fixed",
        start = 112,
        stop = 150,
        out = 8,
        lit = 2,
        match = 1,
        final = true,
      },
    }

    assert.are.same({
      "block 1: stored, start 0.0, 72 bits, 4 bytes out, 0 literals, 0 matches",
      "block 2: stored, start 9.0, 40 bits, 0 bytes out, 0 literals, 0 matches",
      "block 3: fixed, final, start 14.0, 38 bits, 8 bytes out, 2 literals, 1 match",
    }, Blocks.render(blocks))
  end)

  it("renders an unaligned dynamic block with singular counts", function()
    local blocks = {
      {
        kind = "dynamic",
        start = 10,
        stop = 11,
        out = 1,
        lit = 1,
        match = 2,
        final = false,
      },
    }

    assert.are.same({
      "block 1: dynamic, start 1.2, 1 bit, 1 byte out, 1 literal, 2 matches",
    }, Blocks.render(blocks))
  end)

  it("returns fresh lines without LF, preserves inputs, and performs no I/O", function()
    local blocks = {
      {
        kind = "dynamic",
        start = 10,
        stop = 11,
        out = 1,
        lit = 1,
        match = 2,
        final = false,
      },
    }
    local original_blocks = {
      {
        kind = "dynamic",
        start = 10,
        stop = 11,
        out = 1,
        lit = 1,
        match = 2,
        final = false,
      },
    }
    local expected = {
      "block 1: dynamic, start 1.2, 1 bit, 1 byte out, 1 literal, 2 matches",
    }
    local original_print = print
    local original_open = io.open
    local original_write = io.write

    local function reject_io()
      error("renderer attempted I/O", 0)
    end

    _G.print = reject_io
    rawset(io, "open", reject_io)
    rawset(io, "write", reject_io)
    local ok, first = pcall(Blocks.render, blocks)
    _G.print = original_print
    rawset(io, "open", original_open)
    rawset(io, "write", original_write)

    if not ok then
      error(first, 0)
    end

    local second = Blocks.render(blocks)
    assert.is_true(first ~= second)
    assert.are.same(expected, first)
    assert.are.same(expected, second)
    assert.is_nil(second[1]:find("\n", 1, true))

    first[1] = "changed"
    assert.are.same(expected, Blocks.render(blocks))
    assert.are.same(original_blocks, blocks)
  end)
end)
