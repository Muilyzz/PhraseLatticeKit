import Foundation

/// Musical phrase boundary anchored at an absolute score tick.
///
/// A **fold hinge**: the only sites where meter statements may sit. Unioned
/// with the default 4-bar grid by ``ScorePhrasePolicy`` — pins add hinges,
/// they never replace the grid.
public struct PhraseBoundary: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var tick: ScoreTick

    public init(id: UUID = UUID(), tick: ScoreTick) {
        self.id = id
        self.tick = tick
    }
}

/// Visual system / line break anchored at an absolute score tick.
///
/// Pure layout (soft wrap) — meter, tempo, and alignment never change here.
/// The musical twin is ``PhraseBoundary``; keeping the two distinct is a core
/// design claim of this kit.
public struct SystemBreak: Sendable, Codable, Equatable, Hashable, Identifiable {
    public var id: UUID
    public var tick: ScoreTick

    public init(id: UUID = UUID(), tick: ScoreTick) {
        self.id = id
        self.tick = tick
    }
}
