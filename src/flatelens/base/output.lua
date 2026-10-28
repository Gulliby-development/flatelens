local Text = require("flatelens.base.text")

local Output = {}
Output.__index = Output

function Output.new()
  return setmetatable({
    out = {},
    err = {},
  }, Output)
end

function Output:write_out(text)
  self.out[#self.out + 1] = text
end

function Output:write_err(text)
  self.err[#self.err + 1] = text
end

function Output:write_problems(name, problems, to_err)
  local target = to_err and self.err or self.out

  for _, problem in ipairs(problems) do
    target[#target + 1] =
      string.format("%s: %s %s at %s\n", name, problem.code, problem.text, Text.at(problem.pos))
  end
end

function Output:stdout()
  return table.concat(self.out)
end

function Output:stderr()
  return table.concat(self.err)
end

return Output
