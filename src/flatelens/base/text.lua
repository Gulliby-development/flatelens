local Text = {}

function Text.plural(count, word)
  local suffix = ""
  if count ~= 1 then
    suffix = word:sub(-2) == "ch" and "es" or "s"
  end

  return string.format("%d %s%s", count, word, suffix)
end

function Text.at(bit_pos)
  return string.format("%d.%d", bit_pos // 8, bit_pos % 8)
end

function Text.hex(value, width)
  local result = string.format("%x", value)
  if #result < width then
    result = string.rep("0", width - #result) .. result
  end
  return result
end

function Text.shown(bytes)
  local parts = {}
  for index = 1, #bytes do
    local byte = bytes:byte(index)
    if byte == 92 then
      parts[#parts + 1] = "\\\\"
    elseif byte == 34 then
      parts[#parts + 1] = '\\"'
    elseif byte >= 0x20 and byte <= 0x7E then
      parts[#parts + 1] = string.char(byte)
    else
      parts[#parts + 1] = string.format("\\x%02x", byte)
    end
  end
  return table.concat(parts)
end

function Text.lines(list)
  if #list == 0 then
    return ""
  end
  return table.concat(list, "\n") .. "\n"
end

return Text
