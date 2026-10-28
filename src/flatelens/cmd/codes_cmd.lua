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

function CodesCmd.run(settings, out)
  local lengths = {}

  for _, operand in ipairs(settings.operands) do
    local length, repetition = parse_operand(operand)
    local total = #lengths + repetition
    if total > 288 then
      Failure.raise(2, string.format("flatelens: too many lengths: %d (maximum 288)", total))
    end

    for _ = 1, repetition do
      lengths[#lengths + 1] = length
    end
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
