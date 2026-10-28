-- BitReader reads LSB-first integer fields while preserving absolute bit positions.
local Problem = require("flatelens.model.problem")

local BitReader = {}
BitReader.__index = BitReader

-- Create a reader over data, starting at the absolute bit offset start_bit (default 0).
function BitReader.new(data, start_bit)
  return setmetatable({
    data = data,
    next_bit = start_bit or 0,
  }, BitReader)
end

-- Read count bits as an integer with the first bit in the least significant position.
function BitReader:read(count)
  if count == 0 then
    return 0
  end

  if self.next_bit + count > #self.data * 8 then
    error(Problem.truncated(#self.data), 0)
  end

  local value = 0
  for index = 0, count - 1 do
    local absolute_bit = self.next_bit + index
    local byte_index = absolute_bit // 8 + 1
    local bit_index = absolute_bit % 8
    local bit = (self.data:byte(byte_index) >> bit_index) & 1
    value = value | (bit << index)
  end

  self.next_bit = self.next_bit + count
  return value
end

-- Return the absolute bit offset of the next bit to read.
function BitReader:position()
  return self.next_bit
end

-- Skip to the next byte boundary, keeping an already aligned position unchanged.
function BitReader:align()
  self.next_bit = ((self.next_bit + 7) // 8) * 8
end

return BitReader
