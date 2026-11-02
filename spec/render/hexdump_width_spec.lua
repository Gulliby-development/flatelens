local Hexdump = require("flatelens.render.hexdump")

describe("Hexdump.render with a width", function()
  it("keeps 16 bytes per row when no width is given", function()
    assert.are.same(
      Hexdump.render("0123456789abcdefX", 0, 16),
      Hexdump.render("0123456789abcdefX", 0, 16, 16)
    )
    assert.are.same(Hexdump.render("abc", 0, 256), Hexdump.render("abc", 0, 256, 16))
  end)

  it("cuts rows at the width and pads the hex field of a short row", function()
    assert.are.same({
      "00000000  61 62 63  |abc|",
      "00000003  64 65     |de|",
    }, Hexdump.render("abcde", 0, 256, 3))
    assert.are.same({
      "00000000  61 62 63 64 65  |abcde|",
    }, Hexdump.render("abcde", 0, 256, 5))
    assert.are.same({
      "00000000  61 62 63 64 65        |abcde|",
    }, Hexdump.render("abcde", 0, 256, 7))
  end)

  it("renders one byte per row with a width of 1", function()
    assert.are.same({
      "00000001  62  |b|",
      "00000002  63  |c|",
      "... 2 bytes more",
    }, Hexdump.render("abcde", 1, 2, 1))
  end)

  it("counts the unrendered bytes the same way for every width", function()
    assert.are.same({
      "00000000  61 62  |ab|",
      "... 1 byte more",
    }, Hexdump.render("abc", 0, 2, 2))
    assert.are.same({ "... 3 bytes more" }, Hexdump.render("abc", 0, 0, 2))
    assert.are.same({}, Hexdump.render("abc", 3, 4, 2))
  end)

  it("numbers rows by their absolute offsets", function()
    assert.are.same({
      "0000000a  6b 6c 6d  |klm|",
      "0000000d  6e        |n|",
    }, Hexdump.render("abcdefghijklmn", 10, 256, 3))
  end)

  it("shows bytes outside 0x20 to 0x7e as dots in every width", function()
    assert.are.same({
      "00000000  1f 20  |. |",
      "00000002  7e 7f  |~.|",
    }, Hexdump.render(string.char(0x1f, 0x20, 0x7e, 0x7f), 0, 256, 2))
  end)
end)
