local Failure = require("flatelens.base.failure")
local Problem = require("flatelens.model.problem")

describe("Failure", function()
  it("preserves constructor fields and has a distinct identity", function()
    local failure = Failure.new(2, "oops")

    assert.are.equal(2, failure.exit_code)
    assert.are.equal("oops", failure.message)
    assert.is_true(Failure.is(failure))
    assert.is_false(Problem.is(failure))
  end)

  it("raises a recognized failure with its fields", function()
    local ok, raised = pcall(function()
      Failure.raise(2, "oops")
    end)

    assert.is_false(ok)
    assert.is_true(Failure.is(raised))
    assert.are.equal(2, raised.exit_code)
    assert.are.equal("oops", raised.message)
  end)

  it("preserves constructed Failure and Problem identity through pcall", function()
    local failure = Failure.new(2, "oops")
    local problem = Problem.new("X", "text", 10)
    local failure_ok, raised_failure = pcall(function()
      error(failure, 0)
    end)
    local problem_ok, raised_problem = pcall(function()
      error(problem, 0)
    end)

    assert.is_false(failure_ok)
    assert.are.equal(failure, raised_failure)
    assert.is_false(problem_ok)
    assert.are.equal(problem, raised_problem)
    assert.is_true(Problem.is(problem))
    assert.is_false(Failure.is(problem))
  end)

  it("rejects nil, plain tables and strings", function()
    assert.is_false(Failure.is(nil))
    assert.is_false(Failure.is({}))
    assert.is_false(Failure.is("oops"))
    assert.is_false(Problem.is(nil))
    assert.is_false(Problem.is({}))
    assert.is_false(Problem.is("oops"))
  end)

  it("rethrows unrelated table and string errors unchanged", function()
    local table_error = {}
    local string_error = "unrelated error"

    local function rethrow_unrelated(value)
      local ok, err = pcall(function()
        error(value, 0)
      end)
      if not ok then
        error(err, 0)
      end
    end

    local table_ok, raised_table = pcall(function()
      rethrow_unrelated(table_error)
    end)
    local string_ok, raised_string = pcall(function()
      rethrow_unrelated(string_error)
    end)

    assert.is_false(table_ok)
    assert.are.equal(table_error, raised_table)
    assert.is_false(string_ok)
    assert.are.equal(string_error, raised_string)
  end)
end)
