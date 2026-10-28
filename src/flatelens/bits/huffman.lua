-- Huffman builds canonical codes and decodes them through a bit-reader interface.
local Huffman = {}
Huffman.__index = Huffman

-- Lengths and codes are 1-based lists: index symbol + 1 stores that symbol.
function Huffman.build(lengths)
  local counts = {}
  local used = 0
  local max = 0

  for index = 1, #lengths do
    local length = lengths[index]
    if length > 0 then
      counts[length] = (counts[length] or 0) + 1
      used = used + 1
      if length > max then
        max = length
      end
    end
  end

  local numerator = 0
  for index = 1, #lengths do
    local length = lengths[index]
    if length > 0 then
      numerator = numerator + (1 << (max - length))
    end
  end

  local denominator = 1 << max
  local status
  if used == 0 then
    status = "empty"
  elseif numerator > denominator then
    status = "over-subscribed"
  elseif numerator == denominator then
    status = "complete"
  else
    status = "incomplete"
  end

  local codes = {}
  local by_length = {}
  if used > 0 and status ~= "over-subscribed" then
    local next_code = {}
    local code = 0
    for bit_length = 1, max do
      code = (code + (counts[bit_length - 1] or 0)) << 1
      next_code[bit_length] = code
    end

    for index = 1, #lengths do
      local length = lengths[index]
      if length > 0 then
        code = next_code[length]
        codes[index] = code
        by_length[length] = by_length[length] or {}
        by_length[length][code] = index - 1
        next_code[length] = code + 1
      end
    end
  end

  return setmetatable({
    lengths = lengths,
    codes = codes,
    used = used,
    max = max,
    status = status,
    numerator = numerator,
    denominator = denominator,
    _by_length = by_length,
  }, Huffman)
end

-- Decode canonical bits most-significant first, retaining the symbol's start position.
function Huffman:decode(reader)
  local start_pos = reader:position()
  local code = 0

  for bit_length = 1, 15 do
    code = (code << 1) | reader:read(1)
    local candidates = self._by_length[bit_length]
    if candidates then
      local symbol = candidates[code]
      if symbol ~= nil then
        return symbol, start_pos
      end
    end
  end

  return nil, start_pos
end

return Huffman
