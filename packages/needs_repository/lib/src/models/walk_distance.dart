/// How far a seat is from the member's barrio, in blocks.
///
/// Measured between barrio centroids, like the solver's `withinTenBlocks`
/// rule: a block is 100 m. The bands scale with the farthest walk to a ronda,
/// which is 10 blocks in Ciudad de la Costa and 15 in Montevideo
/// (`Barrio.walkBlocks`).
enum WalkDistance {
  /// Up to half the farthest walk: 5 blocks, or 7.5 in Montevideo.
  near,

  /// Up to the farthest walk.
  medium,

  /// More than the farthest walk: the solver never seats it.
  far;

  /// The band a walk of [blocks] falls in, where a ronda is at most
  /// [maxBlocks] away.
  factory fromBlocks(num blocks, {num maxBlocks = defaultMaxBlocks}) {
    if (blocks <= maxBlocks / 2) return near;
    if (blocks <= maxBlocks) return medium;
    return far;
  }

  /// The walk from [memberBarrio] to a seat, read from the seat's
  /// [blocksFrom] table (blocks from each barrio's centroid to the seat's),
  /// where a ronda is at most [maxBlocks] away.
  ///
  /// A barrio the table does not list reads as [far]: a seat the phone cannot
  /// place must not pass "caminar mucho".
  factory forMember({
    required String memberBarrio,
    required Map<String, num> blocksFrom,
    num maxBlocks = defaultMaxBlocks,
  }) {
    final blocks = blocksFrom[memberBarrio];
    return blocks == null
        ? far
        : WalkDistance.fromBlocks(blocks, maxBlocks: maxBlocks);
  }

  /// The shortest of [walks], for a member who meets from more than one
  /// barrio (casa and trabajo): a seat is as near as their nearest barrio.
  /// [far] when there are none.
  static WalkDistance nearest(Iterable<WalkDistance> walks) =>
      walks.fold(far, (best, walk) => walk.index < best.index ? walk : best);

  /// The farthest walk outside Montevideo, in blocks.
  static const defaultMaxBlocks = 10;
}
