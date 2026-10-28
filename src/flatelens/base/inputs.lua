local Failure = require("flatelens.base.failure")

local Inputs = {}

function Inputs.display_name(path)
  if path == "-" then
    return "<stdin>"
  end

  return path
end

local function hex_value(codepoint)
  if codepoint >= 48 and codepoint <= 57 then
    return codepoint - 48
  end
  if codepoint >= 65 and codepoint <= 70 then
    return codepoint - 65 + 10
  end
  if codepoint >= 97 and codepoint <= 102 then
    return codepoint - 97 + 10
  end

  return nil
end

local function invalid_character(codepoint, name, line, column)
  local character
  if codepoint >= 0x20 and codepoint <= 0x7E then
    character = "'" .. string.char(codepoint) .. "'"
  else
    character = string.format("U+%04X", codepoint)
  end

  Failure.raise(
    2,
    string.format(
      "flatelens: %s: invalid hex character %s at line %d column %d",
      name,
      character,
      line,
      column
    )
  )
end

function Inputs.decode_hex(text, name)
  if utf8.len(text) == nil then
    Failure.raise(2, string.format("flatelens: %s: not valid UTF-8 text", name))
  end

  local bytes = {}
  local high_nibble
  local line = 1
  local column = 1

  for _, codepoint in utf8.codes(text) do
    local value = hex_value(codepoint)

    if value ~= nil then
      if high_nibble == nil then
        high_nibble = value
      else
        bytes[#bytes + 1] = string.char(high_nibble * 16 + value)
        high_nibble = nil
      end
    elseif codepoint == 10 then
      line = line + 1
      column = 0
    elseif codepoint ~= 32 and codepoint ~= 9 and codepoint ~= 13 then
      invalid_character(codepoint, name, line, column)
    end

    column = column + 1
  end

  if high_nibble ~= nil then
    Failure.raise(2, string.format("flatelens: %s: odd number of hex digits", name))
  end

  return table.concat(bytes)
end

function Inputs.load(path, hex_mode, env)
  local name = Inputs.display_name(path)
  local data

  if path == "-" then
    if not hex_mode then
      Failure.raise(2, "flatelens: standard input needs --hex")
    end
    data = env.stdin()
  else
    data = env.read(path)
    if data == nil then
      Failure.raise(2, string.format("flatelens: %s: cannot read file", path))
    end
  end

  if hex_mode then
    return Inputs.decode_hex(data, name)
  end

  return data
end

return Inputs
