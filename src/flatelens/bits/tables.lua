-- RFC 1951 code lengths, code-length order, and length/distance mappings.
local fixed_lit_lengths = {}
for symbol = 0, 143 do
  fixed_lit_lengths[symbol + 1] = 8
end
for symbol = 144, 255 do
  fixed_lit_lengths[symbol + 1] = 9
end
for symbol = 256, 279 do
  fixed_lit_lengths[symbol + 1] = 7
end
for symbol = 280, 287 do
  fixed_lit_lengths[symbol + 1] = 8
end

local fixed_dist_lengths = {}
for symbol = 0, 31 do
  fixed_dist_lengths[symbol + 1] = 5
end

local cl_order = {
  16,
  17,
  18,
  0,
  8,
  7,
  9,
  6,
  10,
  5,
  11,
  4,
  12,
  3,
  13,
  2,
  14,
  1,
  15,
}

local length_bases = {
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  13,
  15,
  17,
  19,
  23,
  27,
  31,
  35,
  43,
  51,
  59,
  67,
  83,
  99,
  115,
  131,
  163,
  195,
  227,
  258,
}

local length_extras = {
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  1,
  1,
  1,
  1,
  2,
  2,
  2,
  2,
  3,
  3,
  3,
  3,
  4,
  4,
  4,
  4,
  5,
  5,
  5,
  5,
  0,
}

local length_base = {}
local length_extra = {}
for index, base in ipairs(length_bases) do
  local symbol = index + 256
  length_base[symbol] = base
  length_extra[symbol] = length_extras[index]
end

local distance_bases = {
  1,
  2,
  3,
  4,
  5,
  7,
  9,
  13,
  17,
  25,
  33,
  49,
  65,
  97,
  129,
  193,
  257,
  385,
  513,
  769,
  1025,
  1537,
  2049,
  3073,
  4097,
  6145,
  8193,
  12289,
  16385,
  24577,
}

local distance_extras = {
  0,
  0,
  0,
  0,
  1,
  1,
  2,
  2,
  3,
  3,
  4,
  4,
  5,
  5,
  6,
  6,
  7,
  7,
  8,
  8,
  9,
  9,
  10,
  10,
  11,
  11,
  12,
  12,
  13,
  13,
}

local distance_base = {}
local distance_extra = {}
for index, base in ipairs(distance_bases) do
  local symbol = index - 1
  distance_base[symbol] = base
  distance_extra[symbol] = distance_extras[index]
end

-- Length lists use symbol + 1 indices; mappings use their actual RFC symbols as keys.
return {
  fixed_lit_lengths = fixed_lit_lengths,
  fixed_dist_lengths = fixed_dist_lengths,
  cl_order = cl_order,
  length_base = length_base,
  length_extra = length_extra,
  distance_base = distance_base,
  distance_extra = distance_extra,
}
