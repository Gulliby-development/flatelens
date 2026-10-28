local Tree = require("flatelens.render.tree")

local function render_without_io(block, index)
  local original_print = print
  local original_open = io.open
  local original_write = io.write
  local function reject_io()
    error("renderer attempted I/O", 0)
  end

  _G.print = reject_io
  rawset(io, "open", reject_io)
  rawset(io, "write", reject_io)
  local ok, result = pcall(Tree.render, block, index)
  _G.print = original_print
  rawset(io, "open", original_open)
  rawset(io, "write", original_write)

  if not ok then
    error(result, 0)
  end
  return result
end

describe("flatelens.render.tree", function()
  it("renders transmitted lengths, maximal runs, and supplied summaries", function()
    local block = {
      hlit = 257,
      hdist = 5,
      hclen = 4,
      cl_lengths = { { 16, 3 }, { 17, 0 }, { 18, 4 }, { 0, 2 } },
      lit_lengths = { 4, 4, 0, 4, 5, 5 },
      dist_lengths = { 0, 0, 0, 0, 0 },
      lit_info = { used = 5, max = 5, status = "incomplete" },
      dist_info = { used = 0, max = 0, status = "empty" },
    }

    assert.are.same({
      "block 3: dynamic, HLIT 257, HDIST 5, HCLEN 4",
      "code length code lengths: 16:3 17:0 18:4 0:2",
      "literal/length lengths: 0-1:4 3:4 4-5:5",
      "distance lengths: none",
      "literal/length code: 5 symbols, max length 5, incomplete",
      "distance code: 0 symbols, max length 0, empty",
    }, Tree.render(block, 3))
  end)

  it("renders single-symbol, equal-run, over-subscribed, and empty fixtures", function()
    local cases = {
      {
        name = "single symbol",
        block = {
          hlit = 257,
          hdist = 1,
          hclen = 4,
          cl_lengths = { { 0, 0 }, { 1, 1 } },
          lit_lengths = { 0, 1 },
          dist_lengths = {},
          lit_info = { used = 1, max = 1, status = "incomplete" },
          dist_info = { used = 0, max = 0, status = "empty" },
        },
        index = 1,
        expected = {
          "block 1: dynamic, HLIT 257, HDIST 1, HCLEN 4",
          "code length code lengths: 0:0 1:1",
          "literal/length lengths: 1:1",
          "distance lengths: none",
          "literal/length code: 1 symbol, max length 1, incomplete",
          "distance code: 0 symbols, max length 0, empty",
        },
      },
      {
        name = "equal run",
        block = {
          hlit = 257,
          hdist = 2,
          hclen = 4,
          cl_lengths = { { 16, 2 }, { 17, 0 } },
          lit_lengths = {},
          dist_lengths = { 1, 1 },
          lit_info = { used = 0, max = 0, status = "empty" },
          dist_info = { used = 2, max = 1, status = "complete" },
        },
        index = 2,
        expected = {
          "block 2: dynamic, HLIT 257, HDIST 2, HCLEN 4",
          "code length code lengths: 16:2 17:0",
          "literal/length lengths: none",
          "distance lengths: 0-1:1",
          "literal/length code: 0 symbols, max length 0, empty",
          "distance code: 2 symbols, max length 1, complete",
        },
      },
      {
        name = "over-subscribed status",
        block = {
          hlit = 257,
          hdist = 3,
          hclen = 4,
          cl_lengths = { { 18, 4 }, { 0, 0 } },
          lit_lengths = {},
          dist_lengths = { 1, 1, 1 },
          lit_info = { used = 0, max = 0, status = "empty" },
          dist_info = { used = 3, max = 1, status = "over-subscribed" },
        },
        index = 4,
        expected = {
          "block 4: dynamic, HLIT 257, HDIST 3, HCLEN 4",
          "code length code lengths: 18:4 0:0",
          "literal/length lengths: none",
          "distance lengths: 0-2:1",
          "literal/length code: 0 symbols, max length 0, empty",
          "distance code: 3 symbols, max length 1, over-subscribed",
        },
      },
      {
        name = "empty lengths",
        block = {
          hlit = 257,
          hdist = 1,
          hclen = 4,
          cl_lengths = { { 17, 0 }, { 18, 0 } },
          lit_lengths = {},
          dist_lengths = {},
          lit_info = { used = 0, max = 0, status = "empty" },
          dist_info = { used = 0, max = 0, status = "empty" },
        },
        index = 5,
        expected = {
          "block 5: dynamic, HLIT 257, HDIST 1, HCLEN 4",
          "code length code lengths: 17:0 18:0",
          "literal/length lengths: none",
          "distance lengths: none",
          "literal/length code: 0 symbols, max length 0, empty",
          "distance code: 0 symbols, max length 0, empty",
        },
      },
    }

    for _, case in ipairs(cases) do
      assert.are.same(case.expected, Tree.render(case.block, case.index), case.name)
    end
  end)

  it("returns fresh line lists, preserves inputs, adds no LF, and performs no I/O", function()
    local block = {
      hlit = 257,
      hdist = 3,
      hclen = 4,
      cl_lengths = { { 16, 3 }, { 17, 0 }, { 18, 4 } },
      lit_lengths = { 2, 2, 3 },
      dist_lengths = { 1, 1 },
      lit_info = { used = 3, max = 3, status = "complete" },
      dist_info = { used = 2, max = 1, status = "complete" },
    }
    local expected = {
      "block 3: dynamic, HLIT 257, HDIST 3, HCLEN 4",
      "code length code lengths: 16:3 17:0 18:4",
      "literal/length lengths: 0-1:2 2:3",
      "distance lengths: 0-1:1",
      "literal/length code: 3 symbols, max length 3, complete",
      "distance code: 2 symbols, max length 1, complete",
    }
    local first = render_without_io(block, 3)
    local second = Tree.render(block, 3)

    assert.is_true(first ~= second)
    assert.are.same(expected, second)
    for _, line in ipairs(second) do
      assert.is_nil(line:find("\n", 1, true))
    end

    first[1] = "changed"
    assert.are.same(expected, Tree.render(block, 3))
    assert.are.same({
      hlit = 257,
      hdist = 3,
      hclen = 4,
      cl_lengths = { { 16, 3 }, { 17, 0 }, { 18, 4 } },
      lit_lengths = { 2, 2, 3 },
      dist_lengths = { 1, 1 },
      lit_info = { used = 3, max = 3, status = "complete" },
      dist_info = { used = 2, max = 1, status = "complete" },
    }, block)
  end)
end)
