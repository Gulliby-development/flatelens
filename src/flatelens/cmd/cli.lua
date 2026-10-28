local Failure = require("flatelens.base.failure")
local Inputs = require("flatelens.base.inputs")
local Options = require("flatelens.base.options")
local Stream = require("flatelens.frame.stream")
local CheckCmd = require("flatelens.cmd.check_cmd")
local CodesCmd = require("flatelens.cmd.codes_cmd")
local DumpCmd = require("flatelens.cmd.dump_cmd")
local InfoCmd = require("flatelens.cmd.info_cmd")
local TreeCmd = require("flatelens.cmd.tree_cmd")

local Cli = {}

local usage = table.concat({
  "usage: flatelens info [--format F] [--hex] FILE",
  "       flatelens blocks [--format F] [--hex] FILE",
  "       flatelens tree [--format F] [--hex] [--block N] FILE",
  "       flatelens dump [--format F] [--hex] [--skip N] [--limit N] FILE",
  "       flatelens check [--format F] [--hex] FILE...",
  "       flatelens codes LENGTH...",
  "",
}, "\n")

local option_specs = {
  info = { format = "value", hex = "flag" },
  blocks = { format = "value", hex = "flag" },
  tree = { format = "value", hex = "flag", block = "value" },
  dump = { format = "value", hex = "flag", skip = "value", limit = "value" },
  check = { format = "value", hex = "flag" },
  codes = {},
}

local valid_formats = {
  auto = true,
  gzip = true,
  zlib = true,
  raw = true,
}

local function command_args(args)
  local result = {}
  for index = 2, #args do
    result[#result + 1] = args[index]
  end
  return result
end

local function parse_settings(command, args)
  local parsed = Options.parse(command_args(args), option_specs[command])
  local format = parsed.values.format or "auto"
  if not valid_formats[format] then
    Failure.raise(2, "flatelens: invalid --format value: " .. format)
  end

  local settings = {
    operands = parsed.operands,
    format = format,
    hex = parsed.flags.hex == true,
  }

  if command == "tree" then
    settings.block = Options.number(parsed, "block", nil, 1)
  elseif command == "dump" then
    settings.skip = Options.number(parsed, "skip", 0, 0)
    settings.limit = Options.number(parsed, "limit", 256, 1)
  end

  if command == "info" or command == "blocks" or command == "tree" or command == "dump" then
    if #settings.operands ~= 1 then
      Failure.raise(2, "flatelens: " .. command .. " needs exactly one file")
    end
  elseif #settings.operands == 0 then
    local noun = command == "check" and "file" or "length"
    Failure.raise(2, "flatelens: " .. command .. " needs at least one " .. noun)
  end

  return settings
end

local function run_command(args, env, out)
  local command = args[1]
  if command == nil then
    out:write_err(usage)
    return 2
  end

  if command == "--help" or command == "-h" then
    out:write_out(usage)
    return 0
  end

  local option_spec = option_specs[command]
  if option_spec == nil then
    Failure.raise(2, "flatelens: unknown command " .. command)
  end

  local settings = parse_settings(command, args)
  if command == "check" then
    return CheckCmd.run(settings, env, out)
  elseif command == "codes" then
    return CodesCmd.run(settings, out)
  end

  local path = settings.operands[1]
  local data = Inputs.load(path, settings.hex, env)
  local name = Inputs.display_name(path)
  local report = Stream.analyse(data, settings.format)

  if command == "info" or command == "blocks" then
    InfoCmd.run(command, report, out)
  elseif command == "tree" then
    TreeCmd.run(report, settings, out)
  else
    DumpCmd.run(report, settings, out)
  end

  out:write_problems(name, report.problems, true)
  return #report.problems > 0 and 1 or 0
end

function Cli.run(args, env, out)
  local ok, result = pcall(run_command, args, env, out)
  if ok then
    return result
  end

  if Failure.is(result) then
    out:write_err(result.message .. "\n")
    return result.exit_code
  end

  error(result, 0)
end

return Cli
