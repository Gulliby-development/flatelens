local Huffman = require("flatelens.bits.huffman")
local Tables = require("flatelens.bits.tables")
local Problem = require("flatelens.model.problem")

local DynamicHeader = {}

local function tree_info(tree)
  return {
    used = tree.used,
    max = tree.max,
    status = tree.status,
  }
end

local function acceptable(tree)
  return tree.status == "complete" or (tree.status == "incomplete" and tree.max == 1)
end

function DynamicHeader.read(reader, block_start)
  local hlit = reader:read(5) + 257
  local hdist = reader:read(5) + 1
  local hclen = reader:read(4) + 4

  if hlit > 286 or hdist > 30 then
    error(Problem.too_many_symbols(block_start, hlit, hdist), 0)
  end

  local code_lengths = {}
  for symbol = 0, 18 do
    code_lengths[symbol + 1] = 0
  end

  local cl_lengths = {}
  for index = 1, hclen do
    local symbol = Tables.cl_order[index]
    local length = reader:read(3)
    code_lengths[symbol + 1] = length
    cl_lengths[index] = { symbol, length }
  end

  local cl_tree = Huffman.build(code_lengths)
  if cl_tree.status ~= "complete" then
    local status = cl_tree.status
    if status == "empty" then
      status = "incomplete"
    end
    error(Problem.code_length_code(block_start, status), 0)
  end

  local all_lengths = {}
  local total = hlit + hdist
  while #all_lengths < total do
    local symbol = cl_tree:decode(reader)
    if symbol == nil then
      error(Problem.bad_repeat(block_start), 0)
    end

    if symbol <= 15 then
      all_lengths[#all_lengths + 1] = symbol
    else
      local count
      local length
      if symbol == 16 then
        count = reader:read(2) + 3
        if #all_lengths == 0 then
          error(Problem.bad_repeat(block_start), 0)
        end
        length = all_lengths[#all_lengths]
      elseif symbol == 17 then
        count = reader:read(3) + 3
        length = 0
      elseif symbol == 18 then
        count = reader:read(7) + 11
        length = 0
      else
        error(Problem.bad_repeat(block_start), 0)
      end

      if #all_lengths + count > total then
        error(Problem.bad_repeat(block_start), 0)
      end

      for _ = 1, count do
        all_lengths[#all_lengths + 1] = length
      end
    end
  end

  local lit_lengths = {}
  for index = 1, hlit do
    lit_lengths[index] = all_lengths[index]
  end

  local dist_lengths = {}
  for index = 1, hdist do
    dist_lengths[index] = all_lengths[hlit + index]
  end

  if lit_lengths[257] == 0 then
    error(Problem.no_end_of_block(block_start), 0)
  end

  local lit_tree = Huffman.build(lit_lengths)
  if not acceptable(lit_tree) then
    error(Problem.litlen_code(block_start, lit_tree.status), 0)
  end

  local dist_tree = Huffman.build(dist_lengths)
  if dist_tree.status ~= "empty" and not acceptable(dist_tree) then
    error(Problem.distance_code(block_start, dist_tree.status), 0)
  end

  return {
    lit_tree = lit_tree,
    dist_tree = dist_tree,
    hlit = hlit,
    hdist = hdist,
    hclen = hclen,
    cl_lengths = cl_lengths,
    lit_lengths = lit_lengths,
    dist_lengths = dist_lengths,
    lit_info = tree_info(lit_tree),
    dist_info = tree_info(dist_tree),
  }
end

return DynamicHeader
