local Failure = require("flatelens.base.failure")
local Huffman = require("flatelens.bits.huffman")
local Text = require("flatelens.base.text")

local CodesCmd = {}

local function parse_operand(operand)
  local length_text, repetition_text = operand:match("^([0-9][0-9]?)x([0-9][0-9]?[0-9]?)$")

  if not length_text then
    length_text = operand:match("^([0-9][0-9]?)$")
  end

  if not length_text then
    Failure.raise(2, "flatelens: invalid length: " .. operand)
  end

  local length = tonumber(length_text)
  if length > 15 then
    Failure.raise(2, "flatelens: invalid length: " .. operand)
  end

  local repetition = repetition_text and tonumber(repetition_text) or 1
  if repetition < 1 or repetition > 288 then
    Failure.raise(2, "flatelens: invalid length: " .. operand)
  end

  return length, repetition
end

local function binary_code(code, length)
  local digits = {}
  for index = length, 1, -1 do
    digits[index] = (code & 1) == 1 and "1" or "0"
    code = code >> 1
  end
  return table.concat(digits)
end

local function parse_number(text, maximum)
  if text and #text <= 3 and tostring(tonumber(text)) == text and tonumber(text) <= maximum then
    return tonumber(text)
  end
  return nil
end

local function parse_symbol_operand(operand)
  local first, last, length_text = operand:match("^([0-9]+)-([0-9]+):([0-9]+)$")
  if not first then
    first, length_text = operand:match("^([0-9]+):([0-9]+)$")
    last = first
  end

  local low = parse_number(first, 287)
  local high = parse_number(last, 287)
  local length = parse_number(length_text, 15)
  if not (low and high and length) or low > high then
    Failure.raise(2, "flatelens: invalid symbol length: " .. operand)
  end

  return low, high, length
end

local function symbol_lengths(operands)
  local lengths = {}
  local highest = -1

  for _, operand in ipairs(operands) do
    local low, high, length = parse_symbol_operand(operand)
    for symbol = low, high do
      if lengths[symbol + 1] ~= nil then
        Failure.raise(2, string.format("flatelens: symbol %d is listed twice", symbol))
      end
      lengths[symbol + 1] = length
    end
    highest = math.max(highest, high)
  end

  for index = 1, highest + 1 do
    lengths[index] = lengths[index] or 0
  end

  return lengths
end

local function repeated_lengths(operands)
  local lengths = {}

  for _, operand in ipairs(operands) do
    local length, repetition = parse_operand(operand)
    local total = #lengths + repetition
    if total > 288 then
      Failure.raise(2, string.format("flatelens: too many lengths: %d (maximum 288)", total))
    end

    for _ = 1, repetition do
      lengths[#lengths + 1] = length
    end
  end

  return lengths
end

function CodesCmd.run(settings, out)
  local operands = settings.operands
  local lengths
  if operands[1]:find(":", 1, true) then
    lengths = symbol_lengths(operands)
  else
    lengths = repeated_lengths(operands)
  end

  local code = Huffman.build(lengths)
  local lines = {}

  if code.status == "empty" then
    lines[1] = "status: empty"
  else
    if code.status ~= "over-subscribed" then
      for index, length in ipairs(lengths) do
        if length > 0 then
          lines[#lines + 1] =
            string.format("%d: %d %s", index - 1, length, binary_code(code.codes[index], length))
        end
      end
    end

    lines[#lines + 1] =
      string.format("status: %s (%d/%d)", code.status, code.numerator, code.denominator)
  end

  out:write_out(Text.lines(lines))
  return 0
end

return CodesCmd
