/// How far a seat is from the member's barrio, in blocks.
///
/// Measured between barrio centroids, like the solver's `withinTenBlocks`
/// rule: a block is 100 m.
enum WalkDistance {
  /// Up to 5 blocks.
  near,

  /// Up to 10 blocks.
  medium,

  /// More than 10 blocks.
  far;

  /// The band a walk of [blocks] falls in.
  factory fromBlocks(num blocks) {
    if (blocks <= nearBlocks) return near;
    if (blocks <= mediumBlocks) return medium;
    return far;
  }

  /// The walk from [memberBarrio] to a seat, read from the seat's
  /// [blocksFrom] table (blocks from each barrio's centroid to the seat's).
  ///
  /// A barrio the table does not list reads as [far]: a seat the phone cannot
  /// place must not pass "caminar mucho".
  factory forMember({
    required String memberBarrio,
    required Map<String, num> blocksFrom,
  }) {
    final blocks = blocksFrom[memberBarrio];
    return blocks == null ? far : WalkDistance.fromBlocks(blocks);
  }

  /// The most blocks a [near] walk takes.
  static const nearBlocks = 5;

  /// The most blocks a [medium] walk takes.
  static const mediumBlocks = 10;
}
