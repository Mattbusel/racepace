import Foundation
import SwiftUI

enum Unit: String, Codable, CaseIterable {
    case mi, km
    var meters: Double { self == .mi ? 1609.344 : 1000 }
    var name: String { self == .mi ? "mile" : "km" }
    var short: String { self == .mi ? "mi" : "km" }
}

struct Distance: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let short: String
    let meters: Double
    static let presets: [Distance] = [
        Distance(name: "5K", short: "5K", meters: 5000),
        Distance(name: "10K", short: "10K", meters: 10000),
        Distance(name: "Half marathon", short: "Half", meters: 21097.5),
        Distance(name: "Marathon", short: "Full", meters: 42195),
        Distance(name: "1 mile", short: "Mile", meters: 1609.344),
        Distance(name: "10 miles", short: "10 mi", meters: 16093.44),
    ]
}

enum Strategy: String, Codable, CaseIterable, Identifiable {
    case even, negative, progressive, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .even: return "Even"
        case .negative: return "Negative split"
        case .progressive: return "Build"
        case .custom: return "Custom"
        }
    }
    var detail: String {
        switch self {
        case .even: return "The same pace every split"
        case .negative: return "Second half a little faster"
        case .progressive: return "Start easy, get quicker every split"
        case .custom: return "Nudge any split yourself"
        }
    }
}

struct Fuel: Codable, Hashable {
    var on = true
    /// Minutes between gels.
    var every = 40
    var firstAt = 40
    var carbs = 25
    var water = true
}

struct Plan: Codable, Hashable {
    var meters: Double = 21097.5
    var name: String = "Half marathon"
    var goal: TimeInterval = 1 * 3600 + 45 * 60
    var unit: Unit = .mi
    var strategy: Strategy = .even
    /// For negative and build: the percentage swing.
    var swing: Double = 3
    /// For custom: seconds added to each split's pace.
    var nudges: [Double] = []
    var fuel = Fuel()
}

struct Race: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var date: Date
    var plan: Plan
    var result: TimeInterval? = nil
}

struct Split: Identifiable {
    let id: Int
    let length: Double      // in units, 1 except the last
    let pace: TimeInterval  // per unit
    let time: TimeInterval  // this split
    let at: TimeInterval    // cumulative
    var label: String
}

struct DB: Codable {
    var plan = Plan()
    var races: [Race] = []
    var recentMeters: Double = 10000
    var recentTime: TimeInterval = 48 * 60 + 30
}

/// Race day: when the gun went, and when each marker was passed.
struct RaceRun: Codable, Equatable {
    var start: Date
    var laps: [Date] = []
}

enum Pace {
    static func splits(_ p: Plan) -> [Split] {
        let units = p.meters / p.unit.meters
        let n = Int(ceil(units - 1e-6))
        guard n > 0, p.goal > 0 else { return [] }
        let lens: [Double] = (0..<n).map { i in i < n - 1 ? 1 : units - Double(n - 1) }
        let avg = p.goal / units
        // Shape factors, then scale so the total is exactly the goal.
        var f: [Double] = (0..<n).map { i in
            let x = n > 1 ? Double(i) / Double(n - 1) : 0
            switch p.strategy {
            case .even: return 1
            case .negative: return x < 0.5 ? 1 + p.swing / 200 : 1 - p.swing / 200
            case .progressive: return 1 + p.swing / 100 * (0.5 - x)
            case .custom: return 1 + (i < p.nudges.count ? p.nudges[i] : 0) / avg
            }
        }
        let total = zip(lens, f).reduce(0) { $0 + $1.0 * $1.1 * avg }
        let k = p.goal / total
        f = f.map { $0 * k }
        var at: TimeInterval = 0
        return (0..<n).map { i in
            let pace = avg * f[i]
            let t = pace * lens[i]
            at += t
            let label = i < n - 1 ? "\(i + 1)" : (lens[i] < 0.999 ? String(format: "%.2f", units) : "\(n)")
            return Split(id: i, length: lens[i], pace: pace, time: t, at: at, label: label)
        }
    }

    static func avgPace(_ p: Plan) -> TimeInterval { p.goal / (p.meters / p.unit.meters) }

    /// Riegel's endurance model: T2 = T1 × (D2 / D1)^1.06.
    static func riegel(from t: TimeInterval, meters d1: Double, to d2: Double) -> TimeInterval { t * pow(d2 / d1, 1.06) }

    /// Gel times for a plan: from `firstAt`, every `every` minutes, before the finish.
    static func gels(_ p: Plan) -> [TimeInterval] {
        guard p.fuel.on, p.goal > 50 * 60 else { return [] }
        var out: [TimeInterval] = []
        var t = TimeInterval(p.fuel.firstAt * 60)
        while t < p.goal - 12 * 60 { out.append(t); t += TimeInterval(p.fuel.every * 60) }
        return out
    }

    /// Where on the course the runner is, in units, at elapsed time t.
    static func position(_ splits: [Split], at t: TimeInterval) -> Double {
        var d = 0.0
        for s in splits {
            if t <= s.at { return d + s.length * (1 - (s.at - t) / s.time) }
            d += s.length
        }
        return d
    }
}

@MainActor
@Observable
final class Store {
    var db: DB
    let demo: Bool
    var run: RaceRun?
    @ObservationIgnored private let url = URL.documentsDirectory.appending(path: "racepace.json")
    @ObservationIgnored private let runURL = URL.documentsDirectory.appending(path: "raceday.json")

    init(demo: Bool) {
        self.demo = demo
        if demo { db = DB(); Demo.fill(self) }
        else {
            db = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(DB.self, from: $0) } ?? DB()
            run = (try? Data(contentsOf: runURL)).flatMap { try? JSONDecoder().decode(RaceRun.self, from: $0) }
        }
    }

    func save() {
        guard !demo else { return }
        if let d = try? JSONEncoder().encode(db) { try? d.write(to: url, options: .atomic) }
        if let run, let d = try? JSONEncoder().encode(run) { try? d.write(to: runURL, options: .atomic) } else { try? FileManager.default.removeItem(at: runURL) }
    }

    var splits: [Split] { Pace.splits(db.plan) }

    func setDistance(_ d: Distance) {
        let old = db.plan.meters
        db.plan.meters = d.meters; db.plan.name = d.name
        // Keep the pace, not the time, when switching distance.
        db.plan.goal = (db.plan.goal / old * d.meters).rounded()
        db.plan.nudges = []
        save()
    }

    func upsert(_ r: Race) {
        if let i = db.races.firstIndex(where: { $0.id == r.id }) { db.races[i] = r } else { db.races.append(r) }
        db.races.sort { $0.date < $1.date }
        save()
    }
    func remove(_ r: Race) { db.races.removeAll { $0.id == r.id }; save() }
}
