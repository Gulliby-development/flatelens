local Cli = require("flatelens.cmd.cli")
local Output = require("flatelens.base.output")

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

describe("codes command", function()
  it("prints the canonical codes and occupancy for the supplied examples", function()
    local cases = {
      {
        args = { "codes", "3", "3", "3", "3", "3", "2", "4", "4" },
        stdout = "0: 3 010\n1: 3 011\n2: 3 100\n3: 3 101\n4: 3 110\n"
          .. "5: 2 00\n6: 4 1110\n7: 4 1111\nstatus: complete (16/16)\n",
      },
      {
        args = { "codes", "2", "1", "3" },
        stdout = "0: 2 10\n1: 1 0\n2: 3 110\nstatus: incomplete (7/8)\n",
      },
      {
        args = { "codes", "1", "1", "1" },
        stdout = "status: over-subscribed (3/2)\n",
      },
      {
        args = { "codes", "1x2" },
        stdout = "0: 1 0\n1: 1 1\nstatus: complete (2/2)\n",
      },
      {
        args = { "codes", "1" },
        stdout = "0: 1 0\nstatus: incomplete (1/2)\n",
      },
      {
        args = { "codes", "0", "0" },
        stdout = "status: empty\n",
      },
      {
        args = { "codes", "03", "2x2", "0", "3" },
        stdout = "0: 3 100\n1: 2 00\n2: 2 01\n4: 3 101\n" .. "status: incomplete (6/8)\n",
      },
      {
        args = { "codes", "15" },
        stdout = "0: 15 000000000000000\nstatus: incomplete (1/32768)\n",
      },
    }

    for _, case in ipairs(cases) do
      local stdout, stderr, status = run(case.args)
      assert.are.equal(case.stdout, stdout, table.concat(case.args, " "))
      assert.are.equal("", stderr, table.concat(case.args, " "))
      assert.are.equal(0, status, table.concat(case.args, " "))
    end
  end)

  it("accepts repetition and expanded-list boundaries with leading zeroes", function()
    local cases = {
      {
        args = { "codes", "03x002" },
        stdout = "0: 3 000\n1: 3 001\nstatus: incomplete (2/8)\n",
      },
      {
        args = { "codes", "0x001" },
        stdout = "status: empty\n",
      },
      {
        args = { "codes", "0x288" },
        stdout = "status: empty\n",
      },
      {
        args = { "codes", "0x287", "0" },
        stdout = "status: empty\n",
      },
      {
        args = { "codes", "1x288" },
        stdout = "status: over-subscribed (288/2)\n",
      },
    }

    for _, case in ipairs(cases) do
      local stdout, stderr, status = run(case.args)
      assert.are.equal(case.stdout, stdout, table.concat(case.args, " "))
      assert.are.equal("", stderr, table.concat(case.args, " "))
      assert.are.equal(0, status, table.concat(case.args, " "))
    end
  end)

  it("rejects empty arity and malformed or out-of-range operands exactly", function()
    local cases = {
      {
        args = { "codes" },
        stderr = "flatelens: codes needs at least one length\n",
      },
      {
        args = { "codes", "16" },
        stderr = "flatelens: invalid length: 16\n",
      },
      {
        args = { "codes", "3x0" },
        stderr = "flatelens: invalid length: 3x0\n",
      },
      {
        args = { "codes", "8x200", "8x100" },
        stderr = "flatelens: too many lengths: 300 (maximum 288)\n",
      },
      {
        args = { "codes", "-1" },
        stderr = "flatelens: unknown option -1\n",
      },
      {
        args = { "codes", "--", "-1" },
        stderr = "flatelens: invalid length: -1\n",
      },
      {
        args = { "codes", "1x289" },
        stderr = "flatelens: invalid length: 1x289\n",
      },
      {
        args = { "codes", "001" },
        stderr = "flatelens: invalid length: 001\n",
      },
      {
        args = { "codes", "1x0001" },
        stderr = "flatelens: invalid length: 1x0001\n",
      },
      {
        args = { "codes", "1X2" },
        stderr = "flatelens: invalid length: 1X2\n",
      },
      {
        args = { "codes", "1x" },
        stderr = "flatelens: invalid length: 1x\n",
      },
      {
        args = { "codes", "x2" },
        stderr = "flatelens: invalid length: x2\n",
      },
      {
        args = { "codes", "+1" },
        stderr = "flatelens: invalid length: +1\n",
      },
      {
        args = { "codes", "1.0" },
        stderr = "flatelens: invalid length: 1.0\n",
      },
      {
        args = { "codes", " 1" },
        stderr = "flatelens: invalid length:  1\n",
      },
      {
        args = { "codes", "1 " },
        stderr = "flatelens: invalid length: 1 \n",
      },
      {
        args = { "codes", "1xx2" },
        stderr = "flatelens: invalid length: 1xx2\n",
      },
      {
        args = { "codes", "16", "--unknown" },
        stderr = "flatelens: unknown option --unknown\n",
      },
    }

    for _, case in ipairs(cases) do
      local stdout, stderr, status = run(case.args)
      assert.are.equal("", stdout, table.concat(case.args, " "))
      assert.are.equal(case.stderr, stderr, table.concat(case.args, " "))
      assert.are.equal(2, status, table.concat(case.args, " "))
    end
  end)
end)
