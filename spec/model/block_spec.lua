local Block = require("flatelens.model.block")

describe("Block", function()
  it("provides independent defaults", function()
    local block = Block.new({})

    assert.are.equal(0, block.lit)
    assert.are.equal(0, block.match)
    assert.are.equal(0, block.out)
    assert.are.equal(false, block.final)
  end)

  it("preserves overrides and additional fields without changing the input", function()
    local fields = {
      lit = 2,
      match = 1,
      out = 8,
      final = true,
      start = 112,
      kind = "fixed",
      label = "sample",
    }
    local block = Block.new(fields)

    assert.are.equal(2, block.lit)
    assert.are.equal(1, block.match)
    assert.are.equal(8, block.out)
    assert.are.equal(true, block.final)
    assert.are.equal(112, block.start)
    assert.are.equal("fixed", block.kind)
    assert.are.equal("sample", block.label)
    assert.are.equal(2, fields.lit)
    assert.are.equal(1, fields.match)
    assert.are.equal(8, fields.out)
    assert.are.equal(true, fields.final)
    assert.are.equal(112, fields.start)
    assert.are.equal("fixed", fields.kind)
    assert.are.equal("sample", fields.label)
  end)

  it("keeps mutations local to one record and leaves future defaults unchanged", function()
    local first = Block.new({ lit = 4 })
    local second = Block.new({})

    first.lit = 9
    first.kind = "fixed"

    assert.are.equal(9, first.lit)
    assert.are.equal("fixed", first.kind)
    assert.are.equal(0, second.lit)
    assert.are.equal(0, second.match)
    assert.are.equal(0, second.out)
    assert.are.equal(false, second.final)
    assert.is_nil(second.kind)

    local future = Block.new({})
    assert.are.equal(0, future.lit)
    assert.are.equal(0, future.match)
    assert.are.equal(0, future.out)
    assert.are.equal(false, future.final)
    assert.is_nil(future.kind)
  end)
end)
