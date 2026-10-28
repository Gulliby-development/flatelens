local Checksum = require("flatelens.sums.checksum")

describe("Checksum", function()
  it("matches independent CRC-32 and Adler-32 vectors", function()
    local vectors = {
      { "", 0x00000000, 0x00000001 },
      { "123456789", 0xCBF43926, 0x091E01DE },
      { "hello", 0x3610A686, 0x062C0215 },
      { "\0", 0xD202EF8D, 0x00010001 },
      { string.char(0xFF), 0xFF000000, 0x01000100 },
    }

    for _, vector in ipairs(vectors) do
      local crc = Checksum.crc32(vector[1])
      local adler = Checksum.adler32(vector[1])
      assert.are.equal(vector[2], crc)
      assert.are.equal(vector[3], adler)
      assert.are.equal("integer", math.type(crc))
      assert.are.equal("integer", math.type(adler))
      assert.is_true(crc >= 0 and crc < 0x100000000)
      assert.is_true(adler >= 0 and adler < 0x100000000)
    end
  end)

  it("reduces Adler-32 accumulators for a modulus-length NUL string", function()
    assert.are.equal(0x00000001, Checksum.adler32(string.rep("\0", 65521)))
  end)

  it("wraps both Adler-32 accumulators for repeated high bytes", function()
    local high_bytes = string.rep(string.char(0xFF), 100000)
    assert.are.equal(0x149A302C, Checksum.adler32(high_bytes))
  end)

  it("keeps each call independent when checksum calls are interleaved", function()
    assert.are.equal(0xCBF43926, Checksum.crc32("123456789"))
    assert.are.equal(0x062C0215, Checksum.adler32("hello"))
    assert.are.equal(0x3610A686, Checksum.crc32("hello"))
    assert.are.equal(0x091E01DE, Checksum.adler32("123456789"))
    assert.are.equal(0xCBF43926, Checksum.crc32("123456789"))
  end)
end)
