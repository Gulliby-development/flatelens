local Problem = require("flatelens.model.problem")
local Text = require("flatelens.base.text")
local Checksum = require("flatelens.sums.checksum")

local Zlib = {}

local LEVELS = {
  "fastest",
  "fast",
  "default",
  "maximum",
}

function Zlib.header(data)
  if #data < 2 then
    error(Problem.truncated(#data), 0)
  end

  local first = data:byte(1)
  local second = data:byte(2)

  if (first * 256 + second) % 31 ~= 0 then
    error(Problem.header_check(), 0)
  end

  local method = first & 0x0F
  if method ~= 8 then
    error(Problem.bad_method(method), 0)
  end

  local cinfo = first >> 4
  if cinfo > 7 then
    error(Problem.window_too_large(cinfo), 0)
  end

  if (second & 0x20) ~= 0 then
    error(Problem.dictionary_required(), 0)
  end

  local window = 1 << (cinfo + 8)
  local level = (second >> 6) + 1

  return {
    start = 2,
    lines = {
      "window: " .. Text.plural(window, "byte"),
      "level: " .. LEVELS[level],
    },
  }
end

function Zlib.trailer(data, pos, out)
  if #data - pos < 4 then
    error(Problem.truncated(#data), 0)
  end

  local stored = string.unpack(">I4", data, pos + 1)
  local computed = Checksum.adler32(out)
  if stored ~= computed then
    return "adler32 mismatch",
      {
        Problem.checksum(pos * 8, "Adler-32", stored, computed),
      }
  end

  return "adler32 ok", {}
end

return Zlib
