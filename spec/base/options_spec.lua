local Failure = require("flatelens.base.failure")
local Options = require("flatelens.base.options")

local option_spec = {
  hex = "flag",
  format = "value",
}

local function assert_failure(ok, failure, expected_message)
  assert.is_false(ok)
  assert.is_true(Failure.is(failure))
  assert.are.equal(2, failure.exit_code)
  assert.are.equal(expected_message, failure.message)
end

describe("Options", function()
  it("parses interspersed options and preserves operand order", function()
    local result =
      Options.parse({ "a", "--hex", "-", "--format=raw", "b", "--format", "gzip" }, option_spec)

    assert.are.same({
      flags = { hex = true },
      values = { format = "gzip" },
      operands = { "a", "-", "b" },
    }, result)
  end)

  it("handles repeated flags and only the first terminator", function()
    local result = Options.parse({ "--hex", "--hex", "--", "--hex", "--" }, option_spec)

    assert.are.same({
      flags = { hex = true },
      values = {},
      operands = { "--hex", "--" },
    }, result)
  end)

  it("consumes option-like values and splits on the first equals sign", function()
    local option_value = Options.parse({ "--format", "--hex" }, option_spec)
    local equals_value = Options.parse({ "--format=a=b" }, option_spec)

    assert.are.same({
      flags = {},
      values = { format = "--hex" },
      operands = {},
    }, option_value)
    assert.are.same({
      flags = {},
      values = { format = "a=b" },
      operands = {},
    }, equals_value)
  end)

  it("returns three empty tables for empty arguments", function()
    local result = Options.parse({}, option_spec)

    assert.are.same({
      flags = {},
      values = {},
      operands = {},
    }, result)
  end)

  it("reports syntax errors in left-to-right order", function()
    local rows = {
      {
        args = { "--x=1", "--hex=1" },
        message = "flatelens: unknown option --x",
      },
      {
        args = { "-1" },
        message = "flatelens: unknown option -1",
      },
      {
        args = { "--hex=1", "--x" },
        message = "flatelens: option --hex takes no value",
      },
      {
        args = { "--format" },
        message = "flatelens: option --format needs a value",
      },
      {
        args = { "--format=" },
        message = "flatelens: option --format needs a non-empty value",
      },
      {
        args = { "--format", "" },
        message = "flatelens: option --format needs a non-empty value",
      },
    }

    for _, row in ipairs(rows) do
      local ok, failure = pcall(Options.parse, row.args, option_spec)
      assert_failure(ok, failure, row.message)
    end
  end)

  it("returns defaults and accepts numeric boundary spellings", function()
    assert.are.equal(256, Options.number({ values = {} }, "limit", 256, 1))
    assert.are.equal(0, Options.number({ values = { skip = "0" } }, "skip", 0, 0))
    assert.are.equal(1, Options.number({ values = { block = "0001" } }, "block", nil, 1))
    assert.are.equal(
      999999999,
      Options.number({ values = { limit = "999999999" } }, "limit", 256, 1)
    )
  end)

  it("rejects numeric values below their minimum", function()
    local rows = {
      {
        values = { limit = "0" },
        name = "limit",
        default = 256,
        minimum = 1,
        message = "flatelens: invalid --limit value: 0",
      },
      {
        values = { block = "0" },
        name = "block",
        default = nil,
        minimum = 1,
        message = "flatelens: invalid --block value: 0",
      },
    }

    for _, row in ipairs(rows) do
      local ok, failure =
        pcall(Options.number, { values = row.values }, row.name, row.default, row.minimum)
      assert_failure(ok, failure, row.message)
    end
  end)

  it("rejects every invalid numeric spelling without normalizing it", function()
    local rows = {
      {
        value = "1000000000",
        message = "flatelens: invalid --limit value: 1000000000",
      },
      {
        value = "-1",
        message = "flatelens: invalid --limit value: -1",
      },
      {
        value = "+1",
        message = "flatelens: invalid --limit value: +1",
      },
      {
        value = "1.0",
        message = "flatelens: invalid --limit value: 1.0",
      },
      {
        value = "1e2",
        message = "flatelens: invalid --limit value: 1e2",
      },
      {
        value = " 1",
        message = "flatelens: invalid --limit value:  1",
      },
      {
        value = "",
        message = "flatelens: invalid --limit value: ",
      },
      {
        value = "١",
        message = "flatelens: invalid --limit value: ١",
      },
    }

    for _, row in ipairs(rows) do
      local ok, failure = pcall(Options.number, { values = { limit = row.value } }, "limit", 256, 1)
      assert_failure(ok, failure, row.message)
    end
  end)
end)
