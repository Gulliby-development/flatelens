local Failure = require("flatelens.base.failure")
local Options = require("flatelens.base.options")

describe("Options.number with a maximum", function()
  it("accepts values from the minimum to the maximum", function()
    assert.are.equal(1, Options.number({ values = { width = "1" } }, "width", 16, 1, 64))
    assert.are.equal(64, Options.number({ values = { width = "64" } }, "width", 16, 1, 64))
    assert.are.equal(7, Options.number({ values = { width = "007" } }, "width", 16, 1, 64))
  end)

  it("returns the default without checking it", function()
    assert.are.equal(16, Options.number({ values = {} }, "width", 16, 1, 64))
    assert.are.equal(100, Options.number({ values = {} }, "width", 100, 1, 64))
  end)

  it("rejects values above the maximum with the usual message", function()
    for _, value in ipairs({ "65", "100", "999999999" }) do
      local ok, failure = pcall(Options.number, { values = { width = value } }, "width", 16, 1, 64)

      assert.is_false(ok)
      assert.is_true(Failure.is(failure))
      assert.are.equal(2, failure.exit_code)
      assert.are.equal("flatelens: invalid --width value: " .. value, failure.message)
    end
  end)

  it("still rejects values below the minimum and malformed values", function()
    for _, value in ipairs({ "0", "-1", "1.5", "abc", "1000000000" }) do
      local ok, failure = pcall(Options.number, { values = { width = value } }, "width", 16, 1, 64)

      assert.is_false(ok)
      assert.are.equal("flatelens: invalid --width value: " .. value, failure.message)
    end
  end)

  it("keeps a call without a maximum unlimited", function()
    assert.are.equal(
      999999999,
      Options.number({ values = { limit = "999999999" } }, "limit", 256, 1)
    )
  end)
end)
