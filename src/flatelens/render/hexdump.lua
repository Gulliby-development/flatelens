local Text = require("flatelens.base.text")

local Hexdump = {}

-- Render bytes from a zero-based skip offset, selecting at most limit bytes.
-- Returns fresh output lines with absolute offsets and does not perform I/O.
-- Each row holds width bytes (default 16).
function Hexdump.render(bytes, skip, limit, width)
  width = width or 16
  local lines = {}
  local available = #bytes - skip

  if available <= 0 then
    return lines
  end

  local selected = math.min(available, limit)
  local position = skip
  local stop = skip + selected

  while position < stop do
    local row_end = math.min(position + width, stop)
    local hex_parts = {}
    local ascii_parts = {}

    for offset = position, row_end - 1 do
      local byte = bytes:byte(offset + 1)
      hex_parts[#hex_parts + 1] = Text.hex(byte, 2)
      ascii_parts[#ascii_parts + 1] = byte >= 0x20 and byte <= 0x7E and string.char(byte) or "."
    end

    local hex_field = table.concat(hex_parts, " ")
    local padding = string.rep(" ", width * 3 - 1 - #hex_field)
    lines[#lines + 1] = Text.hex(position, 8)
      .. "  "
      .. hex_field
      .. padding
      .. "  |"
      .. table.concat(ascii_parts)
      .. "|"

    position = row_end
  end

  local remaining = available - selected
  if remaining > 0 then
    lines[#lines + 1] = "... " .. Text.plural(remaining, "byte") .. " more"
  end

  return lines
end

return Hexdump
