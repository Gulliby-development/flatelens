local BitReader = require("flatelens.bits.bitreader")
local Huffman = require("flatelens.bits.huffman")
local Tables = require("flatelens.bits.tables")
local Block = require("flatelens.model.block")
local Problem = require("flatelens.model.problem")
local DynamicHeader = require("flatelens.inflate.header")

local Decoder = {}

local fixed_lit_tree = Huffman.build(Tables.fixed_lit_lengths)
local fixed_dist_tree = Huffman.build(Tables.fixed_dist_lengths)

local function decode_compressed(reader, lit_tree, dist_tree, fields, history, output)
  while true do
    local symbol, symbol_start = lit_tree:decode(reader)
    if symbol == nil or symbol == 286 or symbol == 287 then
      error(Problem.bad_litlen(symbol_start), 0)
    end

    if symbol <= 255 then
      local byte = symbol
      history[#history + 1] = byte
      output[#output + 1] = string.char(byte)
      fields.lit = fields.lit + 1
      fields.out = fields.out + 1
    elseif symbol == 256 then
      return
    else
      local length = Tables.length_base[symbol] + reader:read(Tables.length_extra[symbol])
      local distance_symbol, distance_start = dist_tree:decode(reader)
      if distance_symbol == nil or distance_symbol == 30 or distance_symbol == 31 then
        error(Problem.bad_distance(distance_start), 0)
      end

      local distance = Tables.distance_base[distance_symbol]
        + reader:read(Tables.distance_extra[distance_symbol])
      if distance > #history then
        error(Problem.too_far(distance_start, distance, #history), 0)
      end

      for _ = 1, length do
        local byte = history[#history - distance + 1]
        history[#history + 1] = byte
        output[#output + 1] = string.char(byte)
        fields.out = fields.out + 1
      end
      fields.match = fields.match + 1
    end
  end
end

local function completed_block(fields, header)
  if header then
    fields.hlit = header.hlit
    fields.hdist = header.hdist
    fields.hclen = header.hclen
    fields.cl_lengths = header.cl_lengths
    fields.lit_lengths = header.lit_lengths
    fields.dist_lengths = header.dist_lengths
    fields.lit_info = header.lit_info
    fields.dist_info = header.dist_info
  end

  return Block.new(fields)
end

function Decoder.run(data, start_bit)
  local reader = BitReader.new(data, start_bit)
  local blocks = {}
  local history = {}
  local output = {}

  local ok, result = pcall(function()
    while true do
      local start = reader:position()
      local final = reader:read(1) == 1
      local block_type = reader:read(2)
      local fields = {
        start = start,
        final = final,
        lit = 0,
        match = 0,
        out = 0,
      }
      local header

      if block_type == 0 then
        fields.kind = "stored"
        reader:align()
        local length = reader:read(16)
        local complement = reader:read(16)
        if length ~= (~complement & 0xFFFF) then
          error(Problem.stored_check(start, length, complement), 0)
        end

        for _ = 1, length do
          local byte = reader:read(8)
          history[#history + 1] = byte
          output[#output + 1] = string.char(byte)
          fields.out = fields.out + 1
        end
      elseif block_type == 1 then
        fields.kind = "fixed"
        decode_compressed(reader, fixed_lit_tree, fixed_dist_tree, fields, history, output)
      elseif block_type == 2 then
        fields.kind = "dynamic"
        header = DynamicHeader.read(reader, start)
        decode_compressed(reader, header.lit_tree, header.dist_tree, fields, history, output)
      else
        error(Problem.reserved_block_type(start), 0)
      end

      fields.stop = reader:position()
      blocks[#blocks + 1] = completed_block(fields, header)
      if final then
        reader:align()
        return reader:position()
      end
    end
  end)

  if not ok then
    if Problem.is(result) then
      return blocks, table.concat(output), reader:position(), result
    end
    error(result, 0)
  end

  return blocks, table.concat(output), result, nil
end

return Decoder
