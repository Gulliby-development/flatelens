-- Renders a stream report as lines without writing to an output stream.
local Text = require("flatelens.base.text")

local Info = {}

-- Returns a fresh list of report lines. The report is not modified.
function Info.render(report)
  local lines = { "format: " .. report.format }

  for _, line in ipairs(report.header) do
    lines[#lines + 1] = line
  end

  local kind_counts = {}
  for _, block in ipairs(report.blocks) do
    kind_counts[block.kind] = (kind_counts[block.kind] or 0) + 1
  end

  local block_count = #report.blocks
  local block_line = "blocks: " .. string.format("%d", block_count)
  if block_count > 0 then
    local kinds = {}
    for _, kind in ipairs({ "stored", "fixed", "dynamic" }) do
      local count = kind_counts[kind] or 0
      if count > 0 then
        kinds[#kinds + 1] = string.format("%d %s", count, kind)
      end
    end
    block_line = block_line .. " (" .. table.concat(kinds, ", ") .. ")"
  end
  lines[#lines + 1] = block_line

  if report.fatal then
    return lines
  end

  local compressed = report.cend - report.cstart
  local uncompressed = #report.out
  lines[#lines + 1] = "compressed: " .. Text.plural(compressed, "byte")
  lines[#lines + 1] = "uncompressed: " .. Text.plural(uncompressed, "byte")

  if uncompressed == 0 then
    lines[#lines + 1] = "ratio: n/a"
  else
    local ratio_tenths = (compressed * 1000 + uncompressed // 2) // uncompressed
    lines[#lines + 1] = string.format("ratio: %d.%d%%", ratio_tenths // 10, ratio_tenths % 10)
  end

  local check = report.format == "raw" and "none" or report.check
  lines[#lines + 1] = "check: " .. check

  if report.trailing > 0 then
    lines[#lines + 1] = "trailing: " .. Text.plural(report.trailing, "byte")
  end

  return lines
end

return Info
