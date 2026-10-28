-- Launcher: puts ../src on the module path, runs the program and exits with its code.
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
