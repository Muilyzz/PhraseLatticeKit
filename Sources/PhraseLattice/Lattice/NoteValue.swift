import Foundation

/// Written note duration relative to a quarter note, with optional single dot.
///
/// Tick coordinates always use quarter-note PPQ (`ScoreTickGrid.ticksPerBeat`).
/// A tempo `beatUnit` changes only display/seconds conversion, not event ticks.
public struct NoteValue: Sendable, Codable, Equatable, Hashable {
    public enum Base: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
        case whole
        case half
        case quarter
        case eighth
        case sixteenth
    }

    public var base: Base
    /// When true, duration is 3/2 of the undotted base (one dot only).
    public var dotted: Bool

    public init(base: Base, dotted: Bool = false) {
        self.base = base
        self.dotted = dotted
    }

    public static let whole = NoteValue(base: .whole)
    public static let half = NoteValue(base: .half)
    public static let quarter = NoteValue(base: .quarter)
    public static let eighth = NoteValue(base: .eighth)
    public static let sixteenth = NoteValue(base: .sixteenth)

    public static let dottedWhole = NoteValue(base: .whole, dotted: true)
    public static let dottedHalf = NoteValue(base: .half, dotted: true)
    public static let dottedQuarter = NoteValue(base: .quarter, dotted: true)
    public static let dottedEighth = NoteValue(base: .eighth, dotted: true)
    public static let dottedSixteenth = NoteValue(base: .sixteenth, dotted: true)

    /// How many quarter notes fit in this value (e.g. half = 2, dotted quarter = 1.5).
    public var quarterNoteMultiplier: Double {
        let undotted: Double
        switch base {
        case .whole: undotted = 4
        case .half: undotted = 2
        case .quarter: undotted = 1
        case .eighth: undotted = 0.5
        case .sixteenth: undotted = 0.25
        }
        return dotted ? undotted * 1.5 : undotted
    }

    /// Duration in score ticks at `ScoreTickGrid.ticksPerBeat` PPQ.
    public var ticks: Int {
        let undotted: Int
        switch base {
        case .whole: undotted = ScoreTickGrid.ticksPerBeat * 4
        case .half: undotted = ScoreTickGrid.ticksPerBeat * 2
        case .quarter: undotted = ScoreTickGrid.ticksPerBeat
        case .eighth: undotted = ScoreTickGrid.ticksPerBeat / 2
        case .sixteenth: undotted = ScoreTickGrid.ticksPerBeat / 4
        }
        return dotted ? undotted + undotted / 2 : undotted
    }
}

/// Beat unit used by tempo markings (same representation as `NoteValue`).
public typealias TempoBeatUnit = NoteValue
