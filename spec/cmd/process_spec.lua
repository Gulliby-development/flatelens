-- Starts the real program; standard input goes through a file because io.popen is one-way.
local function run_program(args_text, stdin_bytes)
  local base = os.tmpname()
  local in_path, err_path = base .. ".in", base .. ".err"
  local handle = assert(io.open(in_path, "wb"))
  handle:write(stdin_bytes)
  handle:close()
  local first = -1
  while arg and arg[first - 1] do
    first = first - 1
  end
  local lua = (arg and arg[first]) or "lua"
  local command =
    string.format('"%s" bin/flatelens.lua %s < "%s" 2> "%s"', lua, args_text, in_path, err_path)
  local windows = package.config:sub(1, 1) == "\\"
  if windows then
    command = '"' .. command .. '"'
  end
  local pipe = assert(io.popen(command, windows and "rb" or "r"))
  local stdout = pipe:read("a")
  local _, _, code = pipe:close()
  local err_handle = assert(io.open(err_path, "rb"))
  local stderr = err_handle:read("a")
  err_handle:close()
  os.remove(in_path)
  os.remove(err_path)
  os.remove(base)
  return stdout:gsub("\r", ""), stderr:gsub("\r", ""), code
end

describe("flatelens real stdin process", function()
  it("decodes invalid and valid hex through the real launcher", function()
    local stdout, stderr, code = run_program("check --hex -", "78 9c " .. string.char(0xff) .. "\n")
    assert.are.equal("checked 0 files, 0 problems\n", stdout)
    assert.are.equal("flatelens: <stdin>: not valid UTF-8 text\n", stderr)
    assert.are.equal(2, code)

    stdout, stderr, code =
      run_program("check --hex -", "78 9c cb 48 cd c9 c9 07 00 06 2c 02 15\r\n")
    assert.are.equal("<stdin>: ok\nchecked 1 file, 0 problems\n", stdout)
    assert.are.equal("", stderr)
    assert.are.equal(0, code)

    stdout, stderr, code =
      run_program("check --hex -", "78 9c cb 48 cd c9 c9 07 00 06 2c 02 16\r\n")
    assert.are.equal(
      "<stdin>: FL021 Adler-32 mismatch: stored 0x062c0216, computed 0x062c0215 at 9.0\n"
        .. "checked 1 file, 1 problem\n",
      stdout
    )
    assert.are.equal("", stderr)
    assert.are.equal(1, code)
  end)
end)
