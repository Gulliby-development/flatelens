local Cli = require("flatelens.cmd.cli")
local Failure = require("flatelens.base.failure")
local Output = require("flatelens.base.output")

local function run(args, files, reader, stdin_data)
  local output = Output.new()
  local read_paths = {}
  local stdin_calls = 0
  local env = {
    read = function(path)
      read_paths[#read_paths + 1] = path
      if reader ~= nil then
        return reader(path)
      end
      return files[path]
    end,
    stdin = function()
      stdin_calls = stdin_calls + 1
      return stdin_data or "unused"
    end,
  }
  local status = Cli.run(args, env, output)
  return output:stdout(), output:stderr(), status, read_paths, stdin_calls
end

local function read_file(path)
  local handle = assert(io.open(path, "rb"))
  local contents = handle:read("a")
  handle:close()
  return contents
end

describe("flatelens.cmd.cli", function()
  it("prints usage, handles help, and rejects unknown commands", function()
    local usage = "usage: flatelens info [--format F] [--hex] FILE\n"
      .. "       flatelens blocks [--format F] [--hex] FILE\n"
      .. "       flatelens tree [--format F] [--hex] [--block N] FILE\n"
      .. "       flatelens dump [--format F] [--hex] [--skip N] [--limit N] FILE\n"
      .. "       flatelens check [--format F] [--hex] FILE...\n"
      .. "       flatelens codes LENGTH...\n"
    local cases = {
      { {}, "", usage, 2 },
      { { "--help", "ignored" }, usage, "", 0 },
      { { "-h", "ignored" }, usage, "", 0 },
      { { "wat" }, "", "flatelens: unknown command wat\n", 2 },
    }

    for _, row in ipairs(cases) do
      local stdout, stderr, status, reads = run(row[1], {})
      assert.are.equal(row[2], stdout)
      assert.are.equal(row[3], stderr)
      assert.are.equal(row[4], status)
      assert.are.equal(0, #reads)
    end

    local unknown_stdout, unknown_stderr, unknown_status = run({ "wat" }, {})
    assert.are.equal("", unknown_stdout)
    assert.are.equal("flatelens: unknown command wat\n", unknown_stderr)
    assert.are.equal(2, unknown_status)
  end)

  it("converts Failure values and rethrows unrelated errors unchanged", function()
    local stdout, stderr, status = run({ "info", "a.hex" }, {}, function()
      error(Failure.new(2, "flatelens: custom"), 0)
    end)
    assert.are.equal("", stdout)
    assert.are.equal("flatelens: custom\n", stderr)
    assert.are.equal(2, status)

    local unrelated = { message = "not a Failure" }
    local ok, err = pcall(run, { "info", "a.hex" }, {}, function()
      error(unrelated, 0)
    end)
    assert.is_false(ok)
    assert.are.equal(unrelated, err)
  end)

  it("reports option syntax, format, numeric, and operand errors exactly", function()
    local cases = {
      { { "info", "--x=1", "a.hex" }, "unknown option --x" },
      { { "info", "--hex=1", "a.hex" }, "option --hex takes no value" },
      { { "info", "--format" }, "option --format needs a value" },
      { { "info", "--format=", "a.hex" }, "option --format needs a non-empty value" },
      { { "info", "--format", "x", "a.hex" }, "invalid --format value: x" },
      { { "tree", "--block", "0", "a.hex" }, "invalid --block value: 0" },
      { { "dump", "--skip", "-1", "a.hex" }, "invalid --skip value: -1" },
      { { "dump", "--limit", "0", "a.hex" }, "invalid --limit value: 0" },
      {
        { "dump", "--limit", "1000000000", "a.hex" },
        "invalid --limit value: 1000000000",
      },
      { { "dump", "--limit", "1.0", "a.hex" }, "invalid --limit value: 1.0" },
      { { "info" }, "info needs exactly one file" },
      { { "blocks", "a", "b" }, "blocks needs exactly one file" },
      { { "tree" }, "tree needs exactly one file" },
      { { "dump", "a", "b" }, "dump needs exactly one file" },
      { { "check" }, "check needs at least one file" },
      { { "codes" }, "codes needs at least one length" },
      { { "codes", "-1" }, "unknown option -1" },
      { { "info", "--block", "1", "a" }, "unknown option --block" },
      { { "blocks", "--skip", "1", "a" }, "unknown option --skip" },
      { { "check", "--limit", "1", "a" }, "unknown option --limit" },
      { { "tree", "--skip", "1", "a" }, "unknown option --skip" },
      { { "dump", "--block", "1", "a" }, "unknown option --block" },
      { { "codes", "--hex", "1" }, "unknown option --hex" },
      { { "tree", "--block", "1.0", "a" }, "invalid --block value: 1.0" },
      {
        { "tree", "--block", "1000000000", "a" },
        "invalid --block value: 1000000000",
      },
      { { "tree", "--block", "+1", "a" }, "invalid --block value: +1" },
      { { "dump", "--skip", "1.0", "a" }, "invalid --skip value: 1.0" },
      {
        { "dump", "--skip", "1000000000", "a" },
        "invalid --skip value: 1000000000",
      },
      { { "dump", "--skip", "+1", "a" }, "invalid --skip value: +1" },
      { { "dump", "--limit", "+1", "a" }, "invalid --limit value: +1" },
    }

    for _, row in ipairs(cases) do
      local stdout, stderr, status, reads = run(row[1], {})
      assert.are.equal("", stdout)
      assert.are.equal("flatelens: " .. row[2] .. "\n", stderr)
      assert.are.equal(2, status)
      assert.are.equal(0, #reads)
    end
  end)

  it("validates syntax before format, format before numbers, and numbers before arity", function()
    local cases = {
      {
        { "dump", "--format", "x", "--limit", "0", "--x" },
        "flatelens: unknown option --x\n",
      },
      {
        { "dump", "--format", "x", "--skip", "x", "--limit", "0" },
        "flatelens: invalid --format value: x\n",
      },
      {
        { "dump", "--skip", "x", "--limit", "0" },
        "flatelens: invalid --skip value: x\n",
      },
      { { "tree", "--block", "0" }, "flatelens: invalid --block value: 0\n" },
      {
        { "info", "--format", "--hex", "a.hex" },
        "flatelens: invalid --format value: --hex\n",
      },
    }

    for _, row in ipairs(cases) do
      local stdout, stderr, status, reads = run(row[1], {})
      assert.are.equal("", stdout)
      assert.are.equal(row[2], stderr)
      assert.are.equal(2, status)
      assert.are.equal(0, #reads)
    end
  end)

  it(
    "accepts interspersed and repeated options, the second terminator operand, and all formats",
    function()
      local hello = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 15"
      local hello_info = "format: zlib\n"
        .. "window: 32768 bytes\n"
        .. "level: default\n"
        .. "blocks: 1 (1 fixed)\n"
        .. "compressed: 7 bytes\n"
        .. "uncompressed: 5 bytes\n"
        .. "ratio: 140.0%\n"
        .. "check: adler32 ok\n"

      local stdout, stderr, status = run(
        { "info", "--hex", "hello.hex", "--format=raw", "--format", "zlib" },
        { ["hello.hex"] = hello }
      )
      assert.are.equal(hello_info, stdout)
      assert.are.equal("", stderr)
      assert.are.equal(0, status)

      local terminated_stdout, terminated_stderr, terminated_status, reads = run(
        { "info", "--hex", "--", "--" },
        { ["--"] = hello }
      )
      assert.are.equal(hello_info, terminated_stdout)
      assert.are.equal("", terminated_stderr)
      assert.are.equal(0, terminated_status)
      assert.are.same({ "--" }, reads)

      local auto_out, auto_err, auto_status = run(
        { "check", "--format", "auto", "--hex", "hello.hex" },
        { ["hello.hex"] = hello }
      )
      assert.are.equal("hello.hex: ok\nchecked 1 file, 0 problems\n", auto_out)
      assert.are.equal("", auto_err)
      assert.are.equal(0, auto_status)

      local zlib_out, zlib_err, zlib_status = run(
        { "check", "--format", "zlib", "--hex", "hello.hex" },
        { ["hello.hex"] = hello }
      )
      assert.are.equal("hello.hex: ok\nchecked 1 file, 0 problems\n", zlib_out)
      assert.are.equal("", zlib_err)
      assert.are.equal(0, zlib_status)

      local gzip_out, gzip_err, gzip_status = run(
        { "check", "--format", "gzip", "--hex", "hello.hex" },
        { ["hello.hex"] = hello }
      )
      assert.are.equal(
        "hello.hex: FL008 not a gzip stream at 0.0\nchecked 1 file, 1 problem\n",
        gzip_out
      )
      assert.are.equal("", gzip_err)
      assert.are.equal(1, gzip_status)

      local raw_out, raw_err, raw_status = run(
        { "check", "--format", "raw", "--hex", "raw.hex" },
        { ["raw.hex"] = "01 00 00 ff ff" }
      )
      assert.are.equal("raw.hex: ok\nchecked 1 file, 0 problems\n", raw_out)
      assert.are.equal("", raw_err)
      assert.are.equal(0, raw_status)
    end
  )

  it("preserves leading zero numeric values and the default dump limit boundary", function()
    local stdout, stderr, status = run(
      { "dump", "--skip", "000", "--limit=001", "--hex", "hello.hex" },
      { ["hello.hex"] = "78 9c cb 48 cd c9 c9 07 00 06 2c 02 15" }
    )
    assert.are.equal(
      "00000000  68"
        .. "\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20"
        .. "\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20"
        .. "\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20\x20"
        .. "  |h|\n... 4 bytes more\n",
      stdout
    )
    assert.are.equal("", stderr)
    assert.are.equal(0, status)

    local raw = string.char(1, 0x2c, 0x01, 0xd3, 0xfe) .. string.rep("a", 300)
    local default_out, default_err, default_status = run({ "dump", "raw.bin" }, {
      ["raw.bin"] = raw,
    })
    local explicit_out, explicit_err, explicit_status = run(
      { "dump", "--skip", "0", "--limit", "256", "raw.bin" },
      { ["raw.bin"] = raw }
    )
    assert.are.equal(default_out, explicit_out)
    assert.is_true(default_out:find("... 44 bytes more\n", 1, true) ~= nil)
    assert.are.equal("", default_err)
    assert.are.equal("", explicit_err)
    assert.are.equal(0, default_status)
    assert.are.equal(0, explicit_status)
  end)

  it("reports file, stdin, and hex decoding failures with exact diagnostics", function()
    local stdout, stderr, status, reads, stdin_calls = run({ "info", "gone.hex" }, {})
    assert.are.equal("", stdout)
    assert.are.equal(
      "flatelens: gone.hex: cannot read file\n",
      stderr,
      "'flatelens: gone.hex: cannot read file\\n'"
    )
    assert.are.equal(2, status)
    assert.are.same({ "gone.hex" }, reads)
    assert.are.equal(0, stdin_calls)

    stdout, stderr, status, reads, stdin_calls = run({ "info", "-" }, {})
    assert.are.equal("", stdout)
    assert.are.equal(
      "flatelens: standard input needs --hex\n",
      stderr,
      "'flatelens: standard input needs --hex\\n'"
    )
    assert.are.equal(2, status)
    assert.are.same({}, reads)
    assert.are.equal(0, stdin_calls)

    stdout, stderr, status, reads, stdin_calls = run(
      { "info", "--hex", "-" },
      {},
      nil,
      "78 9c " .. string.char(0xff)
    )
    assert.are.equal("", stdout)
    assert.are.equal(
      "flatelens: <stdin>: not valid UTF-8 text\n",
      stderr,
      "`info --hex -` with `78 9c ` + byte `0xff`"
    )
    assert.are.equal(2, status)
    assert.are.same({}, reads)
    assert.are.equal(1, stdin_calls)

    local cases = {
      {
        "x.hex",
        "78 9c g",
        "flatelens: x.hex: invalid hex character 'g' at line 1 column 7\n",
      },
      {
        "x.hex",
        "0",
        "flatelens: x.hex: odd number of hex digits\n",
        "'flatelens: x.hex: odd number of hex digits\\n'",
      },
      {
        "unicode.hex",
        "41\n \té",
        "flatelens: unicode.hex: invalid hex character U+00E9 at line 2 column 3\n",
      },
    }
    for _, row in ipairs(cases) do
      stdout, stderr, status, reads = run({ "info", "--hex", row[1] }, { [row[1]] = row[2] })
      assert.are.equal("", stdout)
      assert.are.equal(row[3], stderr, row[4])
      assert.are.equal(2, status)
      assert.are.same({ row[1] }, reads)
    end
  end)

  it("accepts binary files, mixed-case CRLF hex, and names hex stdin", function()
    local binary =
      string.char(0x78, 0x9c, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x06, 0x2c, 0x02, 0x15)
    local hex = "78 9C CB 48 CD C9 C9 07 00 06 2C 02 15\r\n"
    local expected_info = "format: zlib\n"
      .. "window: 32768 bytes\n"
      .. "level: default\n"
      .. "blocks: 1 (1 fixed)\n"
      .. "compressed: 7 bytes\n"
      .. "uncompressed: 5 bytes\n"
      .. "ratio: 140.0%\n"
      .. "check: adler32 ok\n"

    local binary_stdout, binary_stderr, binary_status = run(
      { "info", "hello.bin" },
      { ["hello.bin"] = binary }
    )
    local hex_stdout, hex_stderr, hex_status = run(
      { "info", "--hex", "hello.hex" },
      { ["hello.hex"] = hex }
    )
    assert.are.equal(expected_info, binary_stdout)
    assert.are.equal(binary_stdout, hex_stdout)
    assert.are.equal("", binary_stderr)
    assert.are.equal("", hex_stderr)
    assert.are.equal(0, binary_status)
    assert.are.equal(0, hex_status)

    local stdin_stdout, stdin_stderr, stdin_status, reads, stdin_calls = run(
      { "check", "--hex", "-" },
      {},
      nil,
      hex
    )
    assert.are.equal("<stdin>: ok\nchecked 1 file, 0 problems\n", stdin_stdout)
    assert.are.equal("", stdin_stderr)
    assert.are.equal(0, stdin_status)
    assert.are.same({}, reads)
    assert.are.equal(1, stdin_calls)
  end)

  it("keeps the launcher exact and confines real-process operations to it", function()
    local expected_launcher =
      [=[-- Launcher: puts ../src on the module path, runs the program and exits with its code.
local script = arg[0] or "bin/flatelens.lua"
local root = script:match("^(.*)[/\\]bin[/\\][^/\\]*$") or "."
package.path = root .. "/src/?.lua;" .. package.path

local Cli = require("flatelens.cmd.cli")
local Output = require("flatelens.base.output")

local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then
    return nil
  end
  local data = handle:read("a")
  handle:close()
  return data
end

local env = {
  read = read_file,
  stdin = function()
    return io.stdin:read("a")
  end,
}

local out = Output.new()
local code = Cli.run(arg, env, out)
io.stdout:write(out:stdout())
io.stderr:write(out:stderr())
io.stdout:flush()
os.exit(code)
]=]
    assert.are.equal(expected_launcher, read_file("bin/flatelens.lua"))

    local command_paths = {
      "src/flatelens/cmd/cli.lua",
      "src/flatelens/cmd/info_cmd.lua",
      "src/flatelens/cmd/tree_cmd.lua",
      "src/flatelens/cmd/dump_cmd.lua",
      "src/flatelens/cmd/check_cmd.lua",
      "src/flatelens/cmd/codes_cmd.lua",
    }
    for _, path in ipairs(command_paths) do
      local source = read_file(path)
      assert.is_nil(source:find("print", 1, true), path)
      assert.is_nil(source:find("io.", 1, true), path)
      assert.is_nil(source:find("package.path", 1, true), path)
      assert.is_nil(source:find("os.exit", 1, true), path)
    end

    assert.is_true(
      read_file("src/flatelens/cmd/info_cmd.lua"):find('require("flatelens.render.info")', 1, true)
        ~= nil
    )
    assert.is_true(
      read_file("src/flatelens/cmd/tree_cmd.lua"):find('require("flatelens.render.tree")', 1, true)
        ~= nil
    )
    assert.is_true(
      read_file("src/flatelens/cmd/dump_cmd.lua"):find(
        'require("flatelens.render.hexdump")',
        1,
        true
      ) ~= nil
    )
    assert.is_true(
      read_file("src/flatelens/cmd/check_cmd.lua"):find(
        'require("flatelens.frame.stream")',
        1,
        true
      ) ~= nil
    )
    assert.is_true(
      read_file("src/flatelens/cmd/codes_cmd.lua"):find(
        'require("flatelens.bits.huffman")',
        1,
        true
      ) ~= nil
    )
  end)
end)
