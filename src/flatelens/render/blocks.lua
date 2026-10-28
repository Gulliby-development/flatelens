-- Renders DEFLATE blocks as lines without writing to an output stream.
local Text = require("flatelens.base.text")

local Blocks = {}

-- Returns a fresh list of block lines in their original order.
function Blocks.render(blocks)
  local lines = {}

  for index, block in ipairs(blocks) do
    local description = string.format("block %d: %s", index, block.kind)
    if block.final then
      description = description .. ", final"
    end

    lines[#lines + 1] = string.format(
      "%s, start %s, %s, %s out, %s, %s",
      description,
      Text.at(block.start),
      Text.plural(block.stop - block.start, "bit"),
      Text.plural(block.out, "byte"),
      Text.plural(block.lit, "literal"),
      Text.plural(block.match, "match")
    )
  end

  return lines
end

return Blocks
