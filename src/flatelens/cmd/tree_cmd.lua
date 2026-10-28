local Failure = require("flatelens.base.failure")
local Text = require("flatelens.base.text")
local Tree = require("flatelens.render.tree")

local TreeCmd = {}

local function append_block(lines, block, index)
  for _, line in ipairs(Tree.render(block, index)) do
    lines[#lines + 1] = line
  end
end

function TreeCmd.run(report, settings, out)
  local lines = {}

  if settings.block ~= nil then
    local index = settings.block
    local block = report.blocks[index]

    if block == nil then
      if report.fatal and index > #report.blocks then
        return
      end
      Failure.raise(
        2,
        string.format(
          "flatelens: no block %d (the stream has %s)",
          index,
          Text.plural(#report.blocks, "block")
        )
      )
    end

    if block.kind ~= "dynamic" then
      Failure.raise(2, string.format("flatelens: block %d is %s, not dynamic", index, block.kind))
    end

    append_block(lines, block, index)
  else
    local found_dynamic = false
    for index, block in ipairs(report.blocks) do
      if block.kind == "dynamic" then
        found_dynamic = true
        append_block(lines, block, index)
      end
    end

    if not found_dynamic and #report.problems == 0 then
      lines[1] = "no dynamic blocks"
    end
  end

  out:write_out(Text.lines(lines))
end

return TreeCmd
