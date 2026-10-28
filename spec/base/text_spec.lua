local Text = require("flatelens.base.text")

describe("flatelens.base.text", function()
  it("pluralizes singulars, plurals, and words ending in ch", function()
    assert.are.equal("1 match", Text.plural(1, "match"))
    assert.are.equal("2 matches", Text.plural(2, "match"))
    assert.are.equal("0 bytes", Text.plural(0, "byte"))
    assert.are.equal("1 byte", Text.plural(1, "byte"))
  end)

  it("formats zero-based bit positions at byte boundaries", function()
    assert.are.equal("0.0", Text.at(0))
    assert.are.equal("0.7", Text.at(7))
    assert.are.equal("1.0", Text.at(8))
    assert.are.equal("1.2", Text.at(10))
    assert.are.equal("9.0", Text.at(72))
  end)

  it("formats lowercase hexadecimal with minimum-width padding", function()
    assert.are.equal("00af", Text.hex(175, 4))
    assert.are.equal("1234", Text.hex(4660, 2))
    assert.are.equal("00", Text.hex(0, 2))
    assert.are.equal("0a", Text.hex(10, 2))
    assert.are.equal("df8a7c3b", Text.hex(0xdf8a7c3b, 8))
  end)

  it("escapes non-printable bytes and quotes at ASCII boundaries", function()
    assert.are.equal(
      '\\x00\\x1f \\"\\\\~\\x7f\\xff',
      Text.shown(string.char(0, 31, 32, 34, 92, 126, 127, 255))
    )
  end)

  it("joins lines with a final LF and preserves empty items", function()
    assert.are.equal("a\n\nb\n", Text.lines({ "a", "", "b" }))
    assert.are.equal("", Text.lines({}))
    assert.are.equal("a\n", Text.lines({ "a" }))
  end)
end)
