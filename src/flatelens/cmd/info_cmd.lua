local Info = require("flatelens.render.info")
local Blocks = require("flatelens.render.blocks")
local Text = require("flatelens.base.text")

local InfoCmd = {}

function InfoCmd.run(command, report, out)
  local lines
  if command == "info" then
    lines = Info.render(report)
  else
    lines = Blocks.render(report.blocks)
  end

  out:write_out(Text.lines(lines))
end

return InfoCmd
