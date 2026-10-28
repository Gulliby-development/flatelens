local Failure = require("flatelens.base.failure")
local Inputs = require("flatelens.base.inputs")
local Stream = require("flatelens.frame.stream")
local Text = require("flatelens.base.text")

local CheckCmd = {}

function CheckCmd.run(settings, env, out)
  local files = 0
  local problems = 0
  local read_failed = false

  for _, path in ipairs(settings.operands) do
    local ok, data = pcall(Inputs.load, path, settings.hex, env)
    if not ok then
      if not Failure.is(data) then
        error(data, 0)
      end

      out:write_err(data.message .. "\n")
      read_failed = true
    else
      files = files + 1
      local name = Inputs.display_name(path)
      local report = Stream.analyse(data, settings.format)
      if #report.problems == 0 then
        out:write_out(name .. ": ok\n")
      else
        out:write_problems(name, report.problems, false)
        problems = problems + #report.problems
      end
    end
  end

  out:write_out(
    string.format("checked %s, %s\n", Text.plural(files, "file"), Text.plural(problems, "problem"))
  )

  if read_failed then
    return 2
  end
  if problems > 0 then
    return 1
  end

  return 0
end

return CheckCmd
