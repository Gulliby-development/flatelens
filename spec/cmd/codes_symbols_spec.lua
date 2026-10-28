local Cli = require("flatelens.cmd.cli")
local Output = require("flatelens.base.output")

local LF = string.char(10)

local function run(args)
  local out = Output.new()
  local env = {
    read = function(path)
      error("codes unexpectedly read " .. path)
    end,
    stdin = function()
      error("codes unexpectedly read stdin")
    end,
  }

  local status = Cli.run(args, env, out)
  return out:stdout(), out:stderr(), status
end

describe("codes command with symbol operands", function()
  it("builds a code from the symbol list that tree prints", function()
    local stdout, stderr, status = run({ "codes", "9:1", "10-11:2" })
    assert.are.equal(
      "9: 1 0" .. LF .. "10: 2 10" .. LF .. "11: 2 11" .. LF .. "status: complete (4/4)" .. LF,
      stdout
    )
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)

  it("gives unlisted symbols length 0 whatever the order of the operands", function()
    local stdout, stderr, status = run({ "codes", "2:1", "0-1:2" })
    assert.are.equal(
      "0: 2 10" .. LF .. "1: 2 11" .. LF .. "2: 1 0" .. LF .. "status: complete (4/4)" .. LF,
      stdout
    )
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)

  it("handles a lone symbol and a list of zero lengths", function()
    local stdout, stderr, status = run({ "codes", "5:3" })
    assert.are.equal("5: 3 000" .. LF .. "status: incomplete (1/8)" .. LF, stdout)
    assert.are.equal("", stderr)
    assert.are.equal(0, status)

    stdout, stderr, status = run({ "codes", "0:0" })
    assert.are.equal("status: empty" .. LF, stdout)
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)

  it("rejects malformed symbol operands", function()
    local stdout, stderr, status = run({ "codes", "288:1" })
    assert.are.equal("", stdout)
    assert.are.equal("flatelens: invalid symbol length: 288:1" .. LF, stderr)
    assert.are.equal(2, status)

    stdout, stderr, status = run({ "codes", "3:16" })
    assert.are.equal("", stdout)
    assert.are.equal("flatelens: invalid symbol length: 3:16" .. LF, stderr)
    assert.are.equal(2, status)

    stdout, stderr, status = run({ "codes", "5-2:1" })
    assert.are.equal("", stdout)
    assert.are.equal("flatelens: invalid symbol length: 5-2:1" .. LF, stderr)
    assert.are.equal(2, status)

    stdout, stderr, status = run({ "codes", "007:1" })
    assert.are.equal("", stdout)
    assert.are.equal("flatelens: invalid symbol length: 007:1" .. LF, stderr)
    assert.are.equal(2, status)

    stdout, stderr, status = run({ "codes", "1:1", "3" })
    assert.are.equal("", stdout)
    assert.are.equal("flatelens: invalid symbol length: 3" .. LF, stderr)
    assert.are.equal(2, status)
  end)

  it("rejects a symbol listed twice", function()
    local stdout, stderr, status = run({ "codes", "1:1", "1:2" })
    assert.are.equal("", stdout)
    assert.are.equal("flatelens: symbol 1 is listed twice" .. LF, stderr)
    assert.are.equal(2, status)

    stdout, stderr, status = run({ "codes", "0-2:1", "2:2" })
    assert.are.equal("", stdout)
    assert.are.equal("flatelens: symbol 2 is listed twice" .. LF, stderr)
    assert.are.equal(2, status)
  end)

  it("keeps the repeated-length form when the first operand has no colon", function()
    local stdout, stderr, status = run({ "codes", "3", "5:2" })
    assert.are.equal("", stdout)
    assert.are.equal("flatelens: invalid length: 5:2" .. LF, stderr)
    assert.are.equal(2, status)

    stdout, stderr, status = run({ "codes", "1x2" })
    assert.are.equal("0: 1 0" .. LF .. "1: 1 1" .. LF .. "status: complete (2/2)" .. LF, stdout)
    assert.are.equal("", stderr)
    assert.are.equal(0, status)
  end)
end)
