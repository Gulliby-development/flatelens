local Info = require("flatelens.render.info")

local function render_without_io(report)
  local original_print = print
  local original_open = io.open
  local original_write = io.write
  local function reject_io()
    error("renderer attempted I/O", 0)
  end

  _G.print = reject_io
  rawset(io, "open", reject_io)
  rawset(io, "write", reject_io)
  local ok, result = pcall(Info.render, report)
  _G.print = original_print
  rawset(io, "open", original_open)
  rawset(io, "write", original_write)

  if not ok then
    error(result, 0)
  end
  return result
end

describe("flatelens.render.info", function()
  it("renders the hello report in the requested order", function()
    local report = {
      format = "zlib",
      header = { "window: 32768 bytes", "level: default" },
      blocks = { { kind = "fixed" } },
      fatal = false,
      cstart = 2,
      cend = 9,
      out = "hello",
      check = "adler32 ok",
      trailing = 0,
    }

    assert.are.same({
      "format: zlib",
      "window: 32768 bytes",
      "level: default",
      "blocks: 1 (1 fixed)",
      "compressed: 7 bytes",
      "uncompressed: 5 bytes",
      "ratio: 140.0%",
      "check: adler32 ok",
    }, Info.render(report))
  end)

  it("stops a fatal report before size fields and summarizes kinds in fixed order", function()
    local fatal_report = {
      format = "raw",
      header = {},
      blocks = {},
      fatal = true,
    }
    local mixed_report = {
      format = "gzip",
      header = { "mtime: 1700000000", "os: unix" },
      blocks = {
        { kind = "dynamic" },
        { kind = "stored" },
        { kind = "fixed" },
        { kind = "stored" },
      },
      fatal = true,
    }

    assert.are.same({
      "format: raw",
      "blocks: 0",
    }, Info.render(fatal_report))
    assert.are.same({
      "format: gzip",
      "mtime: 1700000000",
      "os: unix",
      "blocks: 4 (2 stored, 1 fixed, 1 dynamic)",
    }, Info.render(mixed_report))
  end)

  it("formats singular counts and includes a singular trailing count", function()
    local report = {
      format = "raw",
      header = {},
      blocks = {},
      fatal = false,
      cstart = 4,
      cend = 5,
      out = "x",
      check = "ignored for raw",
      trailing = 1,
    }

    assert.are.same({
      "format: raw",
      "blocks: 0",
      "compressed: 1 byte",
      "uncompressed: 1 byte",
      "ratio: 100.0%",
      "check: none",
      "trailing: 1 byte",
    }, Info.render(report))
  end)

  it("renders empty output as n/a without a trailing count", function()
    local report = {
      format = "raw",
      header = {},
      blocks = {},
      fatal = false,
      cstart = 0,
      cend = 0,
      out = "",
      check = "ignored for raw",
      trailing = 0,
    }

    assert.are.same({
      "format: raw",
      "blocks: 0",
      "compressed: 0 bytes",
      "uncompressed: 0 bytes",
      "ratio: n/a",
      "check: none",
    }, Info.render(report))
  end)

  it("rounds integer ratios half up at and around the boundary", function()
    local cases = {
      {
        name = "exact half",
        report = {
          format = "raw",
          header = {},
          blocks = {},
          fatal = false,
          cstart = 0,
          cend = 1,
          out = string.rep("x", 16),
          trailing = 2,
        },
        expected = {
          "format: raw",
          "blocks: 0",
          "compressed: 1 byte",
          "uncompressed: 16 bytes",
          "ratio: 6.3%",
          "check: none",
          "trailing: 2 bytes",
        },
      },
      {
        name = "below half",
        report = {
          format = "raw",
          header = {},
          blocks = {},
          fatal = false,
          cstart = 0,
          cend = 624,
          out = string.rep("x", 10000),
          trailing = 0,
        },
        expected = {
          "format: raw",
          "blocks: 0",
          "compressed: 624 bytes",
          "uncompressed: 10000 bytes",
          "ratio: 6.2%",
          "check: none",
        },
      },
      {
        name = "above half",
        report = {
          format = "raw",
          header = {},
          blocks = {},
          fatal = false,
          cstart = 0,
          cend = 626,
          out = string.rep("x", 10000),
          trailing = 0,
        },
        expected = {
          "format: raw",
          "blocks: 0",
          "compressed: 626 bytes",
          "uncompressed: 10000 bytes",
          "ratio: 6.3%",
          "check: none",
        },
      },
    }

    for _, case in ipairs(cases) do
      assert.are.same(case.expected, Info.render(case.report), case.name)
    end
  end)

  it("counts bytes rather than UTF-8 characters", function()
    local report = {
      format = "raw",
      header = {},
      blocks = {},
      fatal = false,
      cstart = 0,
      cend = 1,
      out = "\195\169",
      trailing = 0,
    }

    assert.are.same({
      "format: raw",
      "blocks: 0",
      "compressed: 1 byte",
      "uncompressed: 2 bytes",
      "ratio: 50.0%",
      "check: none",
    }, Info.render(report))
  end)

  it(
    "returns fresh lines, leaves nested inputs unchanged, adds no LF, and performs no I/O",
    function()
      local report = {
        format = "raw",
        header = { "header line" },
        blocks = { { kind = "stored" } },
        fatal = false,
        cstart = 0,
        cend = 1,
        out = "x",
        check = "ignored for raw",
        trailing = 0,
      }
      local first = render_without_io(report)
      local second = Info.render(report)

      assert.is_true(first ~= second)
      assert.are.same({
        "format: raw",
        "header line",
        "blocks: 1 (1 stored)",
        "compressed: 1 byte",
        "uncompressed: 1 byte",
        "ratio: 100.0%",
        "check: none",
      }, second)
      assert.is_nil(second[1]:find("\n", 1, true))

      first[1] = "changed"
      assert.are.same({
        "format: raw",
        "header line",
        "blocks: 1 (1 stored)",
        "compressed: 1 byte",
        "uncompressed: 1 byte",
        "ratio: 100.0%",
        "check: none",
      }, Info.render(report))
      assert.are.same({
        format = "raw",
        header = { "header line" },
        blocks = { { kind = "stored" } },
        fatal = false,
        cstart = 0,
        cend = 1,
        out = "x",
        check = "ignored for raw",
        trailing = 0,
      }, report)
    end
  )
end)
