local Output = require("flatelens.base.output")
local Problem = require("flatelens.model.problem")

describe("Output", function()
  it("starts with empty independent buffers", function()
    local first = Output.new()
    local second = Output.new()

    assert.are.equal("", first:stdout())
    assert.are.equal("", first:stderr())
    assert.are.equal("", second:stdout())
    assert.are.equal("", second:stderr())

    first:write_out("first")
    first:write_err("error")

    assert.are.equal("first", first:stdout())
    assert.are.equal("error", first:stderr())
    assert.are.equal("", second:stdout())
    assert.are.equal("", second:stderr())
  end)

  it("appends output and error text verbatim to separate streams", function()
    local output = Output.new()

    output:write_out("a")
    output:write_out("b\n")
    output:write_err("e")
    output:write_err("\n")

    assert.are.equal("ab\n", output:stdout())
    assert.are.equal("e\n", output:stderr())
  end)

  it("writes ordered problem lines to the selected stream", function()
    local output = Output.new()
    local problems = {
      Problem.new("FL018", "invalid literal/length code", 3),
      Problem.new("FL019", "invalid distance code", 10),
    }

    output:write_problems("x.hex", problems, false)
    output:write_problems("x.hex", problems, true)

    assert.are.equal(
      "x.hex: FL018 invalid literal/length code at 0.3\n"
        .. "x.hex: FL019 invalid distance code at 1.2\n",
      output:stdout()
    )
    assert.are.equal(
      "x.hex: FL018 invalid literal/length code at 0.3\n"
        .. "x.hex: FL019 invalid distance code at 1.2\n",
      output:stderr()
    )
  end)

  it("leaves buffers unchanged for empty problems and repeated getters", function()
    local output = Output.new()

    output:write_out("before")
    output:write_problems("x.hex", {}, false)
    output:write_problems("x.hex", {}, true)

    assert.are.equal("before", output:stdout())
    assert.are.equal("before", output:stdout())
    assert.are.equal("", output:stderr())
    assert.are.equal("", output:stderr())

    output:write_out(" after")
    output:write_err("problem\n")

    assert.are.equal("before after", output:stdout())
    assert.are.equal("before after", output:stdout())
    assert.are.equal("problem\n", output:stderr())
    assert.are.equal("problem\n", output:stderr())
  end)
end)
