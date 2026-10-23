// Bitboard representation for Chess in Dart.
// Indexing: bit 0 => A8, bit 63 => H1.

extension type const Bitboard(int value) {
  static const Bitboard zero = Bitboard(0);

  Bitboard operator &(Bitboard other) => Bitboard(value & other.value);
  Bitboard operator |(Bitboard other) => Bitboard(value | other.value);
  Bitboard operator ^(Bitboard other) => Bitboard(value ^ other.value);
  Bitboard operator ~() => Bitboard(~value);
  Bitboard operator <<(int shift) =>
      Bitboard((value << shift) & 0xFFFFFFFFFFFFFFFF);
  // Bitboards are unsigned even though native Dart integers are signed.
  Bitboard operator >>(int shift) => Bitboard(value >>> shift);

  // Unsigned right shift
  Bitboard unsignedRightShift(int shift) => Bitboard(value >>> shift);

  bool get isEmpty => value == 0;
  bool get isNotEmpty => value != 0;

  // Get least significant bit mask
  Bitboard lsb() => Bitboard(value & -value);

  // Get index of least significant set bit (0 to 63)
  int lsbIndex() {
    if (value == 0) return -1;
    final lsb = value & -value;
    if (lsb < 0) return 63;
    return lsb.bitLength - 1;
  }

  // Get index of most significant set bit (0 to 63)
  int msbIndex() {
    if (value == 0) return -1;
    if (value < 0) return 63;
    return value.bitLength - 1;
  }

  // Returns number of set bits (popcount / Hamming weight)
  int countOnes() {
    var x = value;
    int count = 0;
    if (x < 0) {
      count = 1;
      x = x & 0x7FFFFFFFFFFFFFFF;
    }
    x = x - ((x >> 1) & 0x5555555555555555);
    x = (x & 0x3333333333333333) + ((x >> 2) & 0x3333333333333333);
    x = (x + (x >> 4)) & 0x0F0F0F0F0F0F0F0F;
    return count + (((x * 0x0101010101010101).toUnsigned(64)) >>> 56);
  }
}
