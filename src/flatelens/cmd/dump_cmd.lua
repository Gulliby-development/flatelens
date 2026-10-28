local Hexdump = require("flatelens.render.hexdump")
local Text = require("flatelens.base.text")

local DumpCmd = {}

function DumpCmd.run(report, settings, out)
  if report.fatal then
    return
  end

  out:write_out(Text.lines(Hexdump.render(report.out, settings.skip, settings.limit)))
end

return DumpCmd
