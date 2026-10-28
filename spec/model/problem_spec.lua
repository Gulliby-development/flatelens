local Failure = require("flatelens.base.failure")
local Problem = require("flatelens.model.problem")

describe("Problem", function()
  it("preserves fields and has an identity distinct from Failure", function()
    local problem = Problem.new("X", "text", 10)
    local failure = Failure.new(2, "oops")

    assert.are.equal("X", problem.code)
    assert.are.equal("text", problem.text)
    assert.are.equal(10, problem.pos)
    assert.is_true(Problem.is(problem))
    assert.is_true(Failure.is(failure))
    assert.is_false(Problem.is(failure))
    assert.is_false(Failure.is(problem))
    assert.is_false(Problem.is({ code = "X", text = "text", pos = 10 }))
    assert.is_false(Problem.is("problem"))
    assert.is_false(Problem.is(nil))
  end)

  it("preserves identity when a Problem is raised and caught", function()
    local problem = Problem.new("X", "text", 10)
    local ok, caught = pcall(function()
      error(problem, 0)
    end)

    assert.is_false(ok)
    assert.is_true(Problem.is(caught))
    assert.is_true(rawequal(problem, caught))
  end)

  it("raises a recognized Failure with its supplied fields", function()
    local ok, caught = pcall(function()
      Failure.raise(2, "oops")
    end)

    assert.is_false(ok)
    assert.is_true(Failure.is(caught))
    assert.are.equal(2, caught.exit_code)
    assert.are.equal("oops", caught.message)
    assert.is_false(Problem.is(caught))
  end)

  it("rethrows unrelated table and string errors unchanged", function()
    local unrelated = { reason = "unrelated" }
    local ok_table, caught_table = pcall(function()
      local inner_ok, err = pcall(function()
        error(unrelated, 0)
      end)
      if not inner_ok then
        error(err, 0)
      end
    end)
    local ok_string, caught_string = pcall(function()
      local inner_ok, err = pcall(function()
        error("unrelated error", 0)
      end)
      if not inner_ok then
        error(err, 0)
      end
    end)

    assert.is_false(ok_table)
    assert.is_true(rawequal(unrelated, caught_table))
    assert.is_false(Problem.is(caught_table))
    assert.is_false(Failure.is(caught_table))
    assert.is_false(ok_string)
    assert.are.equal("unrelated error", caught_string)
    assert.is_false(Problem.is(caught_string))
    assert.is_false(Failure.is(caught_string))
  end)

  it("creates every diagnostic with its exact identity and fields", function()
    local cases = {
      {
        "truncated",
        function()
          return Problem.truncated(4)
        end,
        "FL001",
        "unexpected end of data",
        32,
      },
      {
        "bad_method",
        function()
          return Problem.bad_method(7)
        end,
        "FL002",
        "unsupported compression method 7",
        0,
      },
      {
        "reserved_flags",
        function()
          return Problem.reserved_flags(32)
        end,
        "FL003",
        "reserved gzip flag bits set: 0x20",
        0,
      },
      {
        "header_check",
        function()
          return Problem.header_check()
        end,
        "FL004",
        "zlib header check failed",
        0,
      },
      {
        "window_too_large",
        function()
          return Problem.window_too_large(8)
        end,
        "FL005",
        "zlib window size too large: CINFO 8",
        0,
      },
      {
        "dictionary_required",
        function()
          return Problem.dictionary_required()
        end,
        "FL006",
        "zlib preset dictionary required",
        0,
      },
      {
        "header_crc",
        function()
          return Problem.header_crc(0x77A6, 0x77A7)
        end,
        "FL007",
        "gzip header CRC mismatch: stored 0x77a6, computed 0x77a7",
        0,
      },
      {
        "not_gzip",
        function()
          return Problem.not_gzip()
        end,
        "FL008",
        "not a gzip stream",
        0,
      },
      {
        "reserved_block_type",
        function()
          return Problem.reserved_block_type(10)
        end,
        "FL010",
        "reserved block type 3",
        10,
      },
      {
        "stored_check",
        function()
          return Problem.stored_check(10, 3, 65276)
        end,
        "FL011",
        "stored block length check failed: LEN 3, NLEN 65276",
        10,
      },
      {
        "too_many_symbols",
        function()
          return Problem.too_many_symbols(10, 287, 1)
        end,
        "FL012",
        "too many length or distance symbols: HLIT 287, HDIST 1",
        10,
      },
      {
        "code_length_code",
        function()
          return Problem.code_length_code(10, "over-subscribed")
        end,
        "FL013",
        "code length code is over-subscribed",
        10,
      },
      {
        "code_length_code",
        function()
          return Problem.code_length_code(10, "incomplete")
        end,
        "FL013",
        "code length code is incomplete",
        10,
      },
      {
        "bad_repeat",
        function()
          return Problem.bad_repeat(10)
        end,
        "FL014",
        "invalid code length repeat",
        10,
      },
      {
        "no_end_of_block",
        function()
          return Problem.no_end_of_block(10)
        end,
        "FL015",
        "no end-of-block code (symbol 256 has length 0)",
        10,
      },
      {
        "litlen_code",
        function()
          return Problem.litlen_code(10, "over-subscribed")
        end,
        "FL016",
        "literal/length code is over-subscribed",
        10,
      },
      {
        "litlen_code",
        function()
          return Problem.litlen_code(10, "incomplete")
        end,
        "FL016",
        "literal/length code is incomplete",
        10,
      },
      {
        "distance_code",
        function()
          return Problem.distance_code(10, "over-subscribed")
        end,
        "FL017",
        "distance code is over-subscribed",
        10,
      },
      {
        "distance_code",
        function()
          return Problem.distance_code(10, "incomplete")
        end,
        "FL017",
        "distance code is incomplete",
        10,
      },
      {
        "bad_litlen",
        function()
          return Problem.bad_litlen(3)
        end,
        "FL018",
        "invalid literal/length code",
        3,
      },
      {
        "bad_distance",
        function()
          return Problem.bad_distance(10)
        end,
        "FL019",
        "invalid distance code",
        10,
      },
      {
        "too_far",
        function()
          return Problem.too_far(10, 1, 0)
        end,
        "FL020",
        "distance 1 is more than the 0 bytes written so far",
        10,
      },
      {
        "checksum",
        function()
          return Problem.checksum(72, "Adler-32", 0x062C0214, 0x062C0215)
        end,
        "FL021",
        "Adler-32 mismatch: stored 0x062c0214, computed 0x062c0215",
        72,
      },
      {
        "checksum",
        function()
          return Problem.checksum(360, "CRC-32", 1, 0xDF8A7C3B)
        end,
        "FL021",
        "CRC-32 mismatch: stored 0x00000001, computed 0xdf8a7c3b",
        360,
      },
      {
        "size",
        function()
          return Problem.size(360, 19, 18)
        end,
        "FL022",
        "size mismatch: stored 19, computed 18",
        360,
      },
      {
        "trailing",
        function()
          return Problem.trailing(104, 2)
        end,
        "FL023",
        "2 bytes after the end of the stream",
        104,
      },
      {
        "trailing",
        function()
          return Problem.trailing(104, 1)
        end,
        "FL023",
        "1 byte after the end of the stream",
        104,
      },
    }

    for _, case in ipairs(cases) do
      local problem = case[2]()

      assert.is_true(Problem.is(problem), case[1])
      assert.are.equal(case[3], problem.code, case[1])
      assert.are.equal(case[4], problem.text, case[1])
      assert.are.equal(case[5], problem.pos, case[1])
    end
  end)
end)
