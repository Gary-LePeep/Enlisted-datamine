module sound_field_common shared

def pack(idx0, idx1, val0, val1 : uint) : uint
  return val1 << 24u | val0 << 16u | idx1 << 8u | idx0

def unpack(c : uint; var idx0 : uint&; var idx1 : uint&; var val0 : uint&; var val1 : uint&)
  idx0 = c & 0xff
  idx1 = (c >> 8u) & 0xff
  val0 = (c >> 16u) & 0xff
  val1 = (c >> 24u)

def invalid_biome_index() : uint
  return 0xffu

def empty_cell() : uint
  return pack(invalid_biome_index(), invalid_biome_index(), 0u, 0u)
