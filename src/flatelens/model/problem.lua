local Text = require("flatelens.base.text")

local Problem = {}
Problem.__index = Problem

function Problem.new(code, text, pos)
  return setmetatable({
    code = code,
    text = text,
    pos = pos,
  }, Problem)
end

function Problem.is(value)
  return type(value) == "table" and getmetatable(value) == Problem
end

function Problem.truncated(length)
  return Problem.new("FL001", "unexpected end of data", length * 8)
end

function Problem.bad_method(method)
  return Problem.new("FL002", string.format("unsupported compression method %d", method), 0)
end

function Problem.reserved_flags(bits)
  local text = "reserved gzip flag bits set: 0x" .. Text.hex(bits, 2)
  return Problem.new("FL003", text, 0)
end

function Problem.header_check()
  return Problem.new("FL004", "zlib header check failed", 0)
end

function Problem.window_too_large(cinfo)
  local text = string.format("zlib window size too large: CINFO %d", cinfo)
  return Problem.new("FL005", text, 0)
end

function Problem.dictionary_required()
  return Problem.new("FL006", "zlib preset dictionary required", 0)
end

function Problem.header_crc(stored, computed)
  local text = string.format(
    "gzip header CRC mismatch: stored 0x%s, computed 0x%s",
    Text.hex(stored, 4),
    Text.hex(computed, 4)
  )
  return Problem.new("FL007", text, 0)
end

function Problem.not_gzip()
  return Problem.new("FL008", "not a gzip stream", 0)
end

function Problem.reserved_block_type(pos)
  return Problem.new("FL010", "reserved block type 3", pos)
end

function Problem.stored_check(pos, len, nlen)
  local text = string.format("stored block length check failed: LEN %d, NLEN %d", len, nlen)
  return Problem.new("FL011", text, pos)
end

function Problem.too_many_symbols(pos, hlit, hdist)
  local text = string.format("too many length or distance symbols: HLIT %d, HDIST %d", hlit, hdist)
  return Problem.new("FL012", text, pos)
end

function Problem.code_length_code(pos, status)
  local text = "code length code is " .. status
  return Problem.new("FL013", text, pos)
end

function Problem.bad_repeat(pos)
  return Problem.new("FL014", "invalid code length repeat", pos)
end

function Problem.no_end_of_block(pos)
  return Problem.new("FL015", "no end-of-block code (symbol 256 has length 0)", pos)
end

function Problem.litlen_code(pos, status)
  local text = "literal/length code is " .. status
  return Problem.new("FL016", text, pos)
end

function Problem.distance_code(pos, status)
  local text = "distance code is " .. status
  return Problem.new("FL017", text, pos)
end

function Problem.bad_litlen(pos)
  return Problem.new("FL018", "invalid literal/length code", pos)
end

function Problem.bad_distance(pos)
  return Problem.new("FL019", "invalid distance code", pos)
end

function Problem.too_far(pos, distance, written)
  local text =
    string.format("distance %d is more than the %d bytes written so far", distance, written)
  return Problem.new("FL020", text, pos)
end

function Problem.checksum(pos, name, stored, computed)
  local text = string.format(
    "%s mismatch: stored 0x%s, computed 0x%s",
    name,
    Text.hex(stored, 8),
    Text.hex(computed, 8)
  )
  return Problem.new("FL021", text, pos)
end

function Problem.size(pos, stored, computed)
  local text = string.format("size mismatch: stored %d, computed %d", stored, computed)
  return Problem.new("FL022", text, pos)
end

function Problem.trailing(pos, count)
  local text = Text.plural(count, "byte") .. " after the end of the stream"
  return Problem.new("FL023", text, pos)
end

return Problem
