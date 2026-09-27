import Foundation

/// A runner training for a spring half, for screenshots and the review recording. Never saved.
@MainActor
enum Demo {
    static func fill(_ s: Store) {
        var plan = Plan()
        plan.meters = 21097.5; plan.name = "Half marathon"; plan.goal = 6280  // 1:44:40
        plan.unit = .mi; plan.strategy = .negative; plan.swing = 3
        plan.fuel = Fuel(on: true, every: 35, firstAt: 40, carbs: 25, water: true)
        s.db.plan = plan
        s.db.recentMeters = 10000; s.db.recentTime = 47 * 60 + 52
        let cal = Calendar.current
        func inDays(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: cal.startOfDay(for: Date())) ?? Date() }
        var tenK = Plan(); tenK.meters = 10000; tenK.name = "10K"; tenK.goal = 47 * 60 + 30; tenK.unit = .mi
        var full = Plan(); full.meters = 42195; full.name = "Marathon"; full.goal = 3 * 3600 + 49 * 60; full.unit = .mi; full.strategy = .negative; full.swing = 2
        s.db.races = [
            Race(name: "Riverside Half", date: inDays(37), plan: plan),
            Race(name: "Lakefront Marathon", date: inDays(163), plan: full),
            Race(name: "Turkey Trot 10K", date: inDays(-64), plan: tenK, result: 47 * 60 + 52),
        ]
    }

    /// Seven miles in, a little behind at mile 5 and clawing it back.
    static func run(_ s: Store) -> RaceRun {
        let start = Date().addingTimeInterval(-(58 * 60 + 41))
        let splits = s.splits
        let drift: [Double] = [4, 9, 12, 15, 11, 6, -3]
        let laps = splits.prefix(7).enumerated().map { i, sp in start.addingTimeInterval(sp.at + drift[i]) }
        return RaceRun(start: start, laps: Array(laps))
    }
}
