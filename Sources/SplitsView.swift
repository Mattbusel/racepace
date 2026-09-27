import SwiftUI

/// Every split as a lane: the pace for that mile, and where the clock should read as you pass it.
struct SplitsView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        let p = store.db.plan
        let splits = store.splits
        let gels = pro.unlocked ? Pace.gels(p) : []
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Splits").font(.sprint(34)).foregroundStyle(Track.ink)
                        Text("\(p.name) in \(Fmt.clock(p.goal)) · \(Fmt.pace(Pace.avgPace(p)))/\(p.unit.short) average").font(.body(13, .semibold)).foregroundStyle(Track.dim)
                    }
                    Spacer()
                    UnitToggle()
                }
                .padding(.top, 8)

                Button { router.sheet = .strategy } label: {
                    HStack(spacing: 12) {
                        PaceProfile(splits: splits, avg: Pace.avgPace(p)).frame(width: 90, height: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.strategy.title).font(.sprint(17, .heavy)).foregroundStyle(Track.ink)
                            Text(p.fuel.on && pro.unlocked && !gels.isEmpty ? "\(p.strategy.detail) · \(gels.count) gels" : p.strategy.detail).font(.body(12)).foregroundStyle(Track.dim)
                        }
                        Spacer()
                        Text("Strategy").font(.body(12.5, .bold)).foregroundStyle(Track.tartan)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Track.tartan)
                    }
                    .card(12, radius: 20)
                }
                .buttonStyle(Press())

                VStack(spacing: 0) {
                    header
                    ForEach(splits) { s in
                        let before = s.at - s.time
                        ForEach(gels.filter { $0 > before && $0 <= s.at }, id: \.self) { g in GelRow(at: g, splits: splits, unit: p.unit) }
                        LaneRow(split: s, avg: Pace.avgPace(p), unit: p.unit, half: isHalfway(s, splits))
                    }
                    finish(p)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Track.line))
                .shadow(color: Color(hex: 0x5A3A20, alpha: 0.1), radius: 12, y: 5)

                HStack(spacing: 10) {
                    BigButton(title: "Pace band", icon: "printer.fill", color: Track.ink) { if pro.allow(.band) { router.sheet = .band } }
                    BigButton(title: "Race day", icon: "stopwatch.fill") { if pro.allow(.raceday) { router.raceDay = true } }
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
    }

    var header: some View {
        HStack {
            Text("LANE").frame(width: 58, alignment: .leading)
            Text("PACE").frame(maxWidth: .infinity, alignment: .leading)
            Text("SPLIT").frame(width: 70, alignment: .trailing)
            Text("CLOCK").frame(width: 84, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .heavy)).tracking(1.4).foregroundStyle(Track.dim)
        .padding(.horizontal, 14).frame(height: 32)
        .background(Track.card)
    }

    func finish(_ p: Plan) -> some View {
        HStack {
            Image(systemName: "flag.checkered").font(.system(size: 16, weight: .bold))
            Text("FINISH").font(.sprint(16, .heavy))
            Spacer()
            Text(Fmt.clock(p.goal)).font(.sprint(22, .heavy)).monospacedDigit()
        }
        .foregroundStyle(.white).padding(.horizontal, 16).frame(height: 54)
        .background(Track.clock)
    }

    func isHalfway(_ s: Split, _ all: [Split]) -> Bool {
        let total = all.reduce(0) { $0 + $1.length }
        let before = all.prefix(while: { $0.id < s.id }).reduce(0) { $0 + $1.length }
        return before < total / 2 && before + s.length >= total / 2
    }
}

/// One split as a lane of track: the number painted white on tartan, then the times.
struct LaneRow: View {
    let split: Split
    let avg: TimeInterval
    let unit: Unit
    var half = false
    var body: some View {
        let diff = split.pace - avg
        HStack(spacing: 0) {
            ZStack {
                Tartan()
                Text(split.label).font(.sprint(split.label.count > 3 ? 14 : 22)).foregroundStyle(.white).minimumScaleFactor(0.6)
            }
            .frame(width: 58)
            .overlay(alignment: .trailing) { Rectangle().fill(.white).frame(width: 3) }
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Fmt.pace(split.pace)).font(.mono(16, .bold)).foregroundStyle(Track.ink)
                    if abs(diff) >= 1 {
                        Text((diff < 0 ? "−" : "+") + "\(Int(abs(diff).rounded()))s").font(.mono(11, .bold)).foregroundStyle(diff < 0 ? Track.ahead : Track.behind)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Fmt.clock(split.time)).font(.mono(14)).foregroundStyle(Track.ink2).frame(width: 70, alignment: .trailing)
                Text(Fmt.clock(split.at)).font(.sprint(18, .heavy)).foregroundStyle(Track.ink).monospacedDigit().frame(width: 84, alignment: .trailing)
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 46)
        .background(half ? Track.led.opacity(0.14) : Track.card)
        .overlay(alignment: .bottom) { Rectangle().fill(Track.line).frame(height: 1) }
        .overlay(alignment: .topTrailing) {
            if half { Text("HALFWAY").font(.system(size: 8.5, weight: .heavy)).tracking(1).foregroundStyle(Track.ink2).padding(.trailing, 14).padding(.top, 3) }
        }
    }
}

struct GelRow: View {
    let at: TimeInterval
    let splits: [Split]
    let unit: Unit
    var body: some View {
        let pos = Pace.position(splits, at: at)
        HStack(spacing: 10) {
            Image(systemName: "drop.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Track.sky)
                .frame(width: 58)
            Text("Gel + water at \(Fmt.clock(at))").font(.body(13, .bold)).foregroundStyle(Track.sky)
            Spacer()
            Text(String(format: "%@ %.1f", unit.name, pos)).font(.mono(12)).foregroundStyle(Track.sky.opacity(0.8)).padding(.trailing, 14)
        }
        .frame(height: 32)
        .background(Track.sky.opacity(0.08))
        .overlay(alignment: .bottom) { Rectangle().fill(Track.line).frame(height: 1) }
    }
}

/// Pace per split around a centre line: green bars up are faster than average, red bars down are slower.
struct PaceProfile: View {
    let splits: [Split]
    let avg: TimeInterval
    var body: some View {
        let m = max(4, splits.map { abs(avg - $0.pace) }.max() ?? 4)
        GeometryReader { g in
            let n = CGFloat(max(1, splits.count))
            let gap = max(1, g.size.width / n * 0.22)
            let w = (g.size.width - gap * (n - 1)) / n
            let mid = g.size.height / 2
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Track.ink.opacity(0.25)).frame(width: g.size.width, height: 1).offset(y: mid)
                ForEach(splits) { s in
                    let d = avg - s.pace
                    let h = max(2, CGFloat(abs(d) / m) * (mid - 2))
                    RoundedRectangle(cornerRadius: min(3, w / 3))
                        .fill(d > 0.5 ? Track.ahead : (d < -0.5 ? Track.tartan : Track.ink2))
                        .frame(width: w, height: h)
                        .offset(x: CGFloat(s.id) * (w + gap), y: d >= 0 ? mid - h : mid)
                }
            }
        }
    }
}

// MARK: - Strategy

struct StrategySheet: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State private var sources = false

    var body: some View {
        @Bindable var store = store
        let p = store.db.plan
        let splits = store.splits
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Strategy").font(.sprint(30)).foregroundStyle(Track.ink)
                    Spacer()
                    CloseKnob { dismiss() }
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 10) {
                    PaceProfile(splits: splits, avg: Pace.avgPace(p)).frame(height: 120)
                    HStack {
                        Text("Start").font(.body(11, .bold)).foregroundStyle(Track.dim)
                        Spacer()
                        Text("Faster above the line · slower below").font(.body(11, .bold)).foregroundStyle(Track.dim)
                        Spacer()
                        Text("Finish").font(.body(11, .bold)).foregroundStyle(Track.dim)
                    }
                    HStack {
                        stat("First half", firstHalf(splits))
                        stat("Second half", p.goal - firstHalf(splits))
                    }
                }
                .card(16, radius: 24)

                VStack(spacing: 10) {
                    ForEach(Strategy.allCases) { s in
                        let on = p.strategy == s
                        Button {
                            if s != .even && !pro.allow(.strategy) { return }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                store.db.plan.strategy = s
                                if s == .custom && store.db.plan.nudges.count != splits.count { store.db.plan.nudges = Array(repeating: 0, count: splits.count) }
                            }
                            store.save()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: on ? "largecircle.fill.circle" : "circle").font(.system(size: 20, weight: .bold)).foregroundStyle(on ? Track.tartan : Track.dim.opacity(0.5))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(s.title).font(.sprint(17, .heavy)).foregroundStyle(Track.ink)
                                    Text(s.detail).font(.body(12.5)).foregroundStyle(Track.dim)
                                }
                                Spacer()
                                if s != .even && !pro.unlocked { ProBadge() }
                            }
                            .card(14, radius: 18)
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? Track.tartan : .clear, lineWidth: 2))
                        }
                        .buttonStyle(Press())
                    }
                }
                .sensoryFeedback(.selection, trigger: p.strategy)

                if p.strategy == .negative || p.strategy == .progressive {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            LaneLabel(p.strategy == .negative ? "Difference between halves" : "Swing from start to finish")
                            Spacer()
                            Text(String(format: "%.0f%%", p.swing)).font(.sprint(20, .heavy)).foregroundStyle(Track.tartan)
                        }
                        Slider(value: $store.db.plan.swing, in: 1...8, step: 1).tint(Track.tartan).onChange(of: p.swing) { _, _ in store.save() }
                        Text("Most coaches suggest a small negative split: bank energy early, not time.").font(.body(12)).foregroundStyle(Track.dim)
                    }
                    .card(16, radius: 22)
                }

                if p.strategy == .custom { customNudges(splits) }

                fuel
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
        .sheet(isPresented: $sources) { SourcesView().presentationBackground(Track.paper) }
    }

    func stat(_ l: String, _ t: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(1.2).foregroundStyle(Track.dim)
            Text(Fmt.clock(t)).font(.sprint(22, .heavy)).foregroundStyle(Track.ink).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func firstHalf(_ splits: [Split]) -> TimeInterval {
        let total = splits.reduce(0) { $0 + $1.length }
        var d = 0.0, t = 0.0
        for s in splits {
            if d + s.length <= total / 2 { d += s.length; t += s.time } else { t += s.pace * (total / 2 - d); break }
        }
        return t
    }

    func customNudges(_ splits: [Split]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LaneLabel("Nudge each split")
            Text("Add seconds where there's a hill, take them back on the downhill. The finish time stays the same.").font(.body(12)).foregroundStyle(Track.dim)
            VStack(spacing: 0) {
                ForEach(splits) { s in
                    HStack {
                        Text(s.label).font(.sprint(16, .heavy)).foregroundStyle(Track.tartan).frame(width: 44, alignment: .leading)
                        Text(Fmt.pace(s.pace)).font(.mono(15, .bold)).foregroundStyle(Track.ink)
                        Spacer()
                        let n = s.id < store.db.plan.nudges.count ? store.db.plan.nudges[s.id] : 0
                        Text(n == 0 ? "±0" : (n > 0 ? "+\(Int(n))s" : "\(Int(n))s")).font(.mono(12, .bold)).foregroundStyle(n > 0 ? Track.behind : (n < 0 ? Track.ahead : Track.dim)).frame(width: 44)
                        Stepper("", onIncrement: { nudge(s.id, 5) }, onDecrement: { nudge(s.id, -5) }).labelsHidden()
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .card(14, radius: 22)
    }

    func nudge(_ i: Int, _ d: Double) {
        guard i < store.db.plan.nudges.count else { return }
        store.db.plan.nudges[i] = max(-60, min(120, store.db.plan.nudges[i] + d))
        store.save()
    }

    var fuel: some View {
        @Bindable var store = store
        let p = store.db.plan
        let gels = Pace.gels(p)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                LaneLabel("Fueling", color: Track.sky)
                if !pro.unlocked { ProBadge() }
                Spacer()
                Toggle("", isOn: Binding(get: { p.fuel.on && pro.unlocked }, set: { v in if pro.allow(.fuel) { store.db.plan.fuel.on = v; store.save() } })).labelsHidden().tint(Track.sky)
            }
            if p.fuel.on && pro.unlocked {
                if gels.isEmpty {
                    Text("Under 50 minutes you won't need a gel. Water if it's hot.").font(.body(13)).foregroundStyle(Track.dim)
                } else {
                    HStack {
                        Text("First at").font(.body(14, .semibold)).foregroundStyle(Track.ink)
                        Spacer()
                        Stepper("\(p.fuel.firstAt) min", value: $store.db.plan.fuel.firstAt, in: 15...75, step: 5).font(.mono(14, .bold)).fixedSize()
                    }
                    HStack {
                        Text("Then every").font(.body(14, .semibold)).foregroundStyle(Track.ink)
                        Spacer()
                        Stepper("\(p.fuel.every) min", value: $store.db.plan.fuel.every, in: 15...60, step: 5).font(.mono(14, .bold)).fixedSize()
                    }
                    HStack {
                        Text("Carbs per gel").font(.body(14, .semibold)).foregroundStyle(Track.ink)
                        Spacer()
                        Stepper("\(p.fuel.carbs) g", value: $store.db.plan.fuel.carbs, in: 15...60, step: 5).font(.mono(14, .bold)).fixedSize()
                    }
                    let perHour = Double(gels.count * p.fuel.carbs) / (p.goal / 3600)
                    Text("\(gels.count) gels, about \(Int(perHour.rounded())) g of carbohydrate an hour. Sports nutrition guidance suggests 30 to 60 g an hour for efforts of 1 to 2.5 hours, and up to 90 g for longer ones, practised in training first.")
                        .font(.body(12.5)).foregroundStyle(Track.ink2).fixedSize(horizontal: false, vertical: true)
                }
                Button { sources = true } label: {
                    Label("Sources", systemImage: "book.closed").font(.body(12.5, .bold)).foregroundStyle(Track.sky)
                }
                .buttonStyle(.plain)
            } else {
                Text("Gel and water reminders placed on your splits, and called out in race-day mode.").font(.body(13)).foregroundStyle(Track.dim)
            }
        }
        .card(16, radius: 22)
        .onChange(of: p.fuel) { _, _ in store.save() }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO").font(.system(size: 9.5, weight: .black)).italic().foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Track.tartan))
    }
}

struct SourcesView: View {
    @Environment(\.dismiss) private var dismiss
    static let refs: [(String, String?, String)] = [
        ("Riegel PS. Athletic records and human endurance. American Scientist. 1981;69(3):285–290.", nil,
         "The endurance model behind the race predictor: T2 = T1 × (D2 ÷ D1)^1.06."),
        ("Thomas DT, Erdman KA, Burke LM. Nutrition and Athletic Performance (ACSM joint position statement). Med Sci Sports Exerc. 2016;48(3):543–568.", "https://doi.org/10.1249/MSS.0000000000000852",
         "Carbohydrate during exercise: about 30 to 60 g an hour for 1 to 2.5 hours, up to 90 g an hour beyond that."),
        ("Jeukendrup AE. A step towards personalized sports nutrition: carbohydrate intake during exercise. Sports Med. 2014;44(Suppl 1):S25–S33.", "https://doi.org/10.1007/s40279-014-0148-z",
         "How carbohydrate needs scale with the length of the event, and why to practise race fueling in training."),
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Sources").font(.sprint(28)).foregroundStyle(Track.ink)
                    Spacer()
                    CloseKnob { dismiss() }
                }
                .padding(.top, 24)
                Text("Race Pace does arithmetic on the times you enter. Predictions are an estimate from a well-known model, and fueling numbers are general guidance for healthy adults, not medical advice. Try any fueling plan in training before race day.")
                    .font(.body(14)).foregroundStyle(Track.ink2).fixedSize(horizontal: false, vertical: true)
                ForEach(Array(SourcesView.refs.enumerated()), id: \.offset) { i, r in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)").font(.sprint(14, .heavy)).foregroundStyle(.white).frame(width: 24, height: 24).background(Circle().fill(Track.tartan))
                            Text(r.0).font(.body(13.5, .semibold)).foregroundStyle(Track.ink).fixedSize(horizontal: false, vertical: true)
                        }
                        Text(r.2).font(.body(12.5)).foregroundStyle(Track.dim).padding(.leading, 34).fixedSize(horizontal: false, vertical: true)
                        if let u = r.1, let url = URL(string: u) {
                            Link(destination: url) { Label(u.replacingOccurrences(of: "https://", with: ""), systemImage: "arrow.up.right.square").font(.body(12, .bold)).foregroundStyle(Track.sky) }
                                .padding(.leading, 34)
                        }
                    }
                    .card(14, radius: 18)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
    }
}
