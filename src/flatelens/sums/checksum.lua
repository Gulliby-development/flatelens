local Checksum = {}

local MASK = 0xFFFFFFFF
local CRC_POLYNOMIAL = 0xEDB88320
local ADLER_MODULUS = 65521

function Checksum.crc32(data)
  local crc = MASK
  for index = 1, #data do
    crc = (crc ~ data:byte(index)) & MASK
    for _ = 1, 8 do
      if (crc & 1) ~= 0 then
        crc = ((crc >> 1) ~ CRC_POLYNOMIAL) & MASK
      else
        crc = (crc >> 1) & MASK
      end
    end
  end
  return ~crc & MASK
end

function Checksum.adler32(data)
  local a = 1
  local b = 0
  for index = 1, #data do
    a = (a + data:byte(index)) % ADLER_MODULUS
    b = (b + a) % ADLER_MODULUS
  end
  return ((b << 16) | a) & MASK
end

return Checksum
