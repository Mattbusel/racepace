import SwiftUI

/// The calculator: distance and goal time in, pace out. Change either side and the other follows.
struct PaceView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @State private var editing = false
    @State private var customKm = ""

    var body: some View {
        @Bindable var store = store
        let p = store.db.plan
        let pace = Pace.avgPace(p)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Race Pace").font(.sprint(34)).foregroundStyle(Track.ink)
                    Spacer()
                    UnitToggle()
                }
                .padding(.top, 8)

                distances

                Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { editing.toggle() } } label: {
                    FinishClock(time: Fmt.clock(p.goal, forceHours: p.goal >= 3600), caption: "Goal · \(p.name) · tap to set", height: 64)
                }
                .buttonStyle(Press())
                if editing {
                    TimeWheels(seconds: $store.db.plan.goal, maxHours: 9).onChange(of: store.db.plan.goal) { _, _ in store.db.plan.nudges = []; store.save() }
                        .card(8, radius: 22)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                paceCard(pace)
                ladder(pace)

                HStack(spacing: 10) {
                    BigButton(title: "See splits", icon: "list.number") { withAnimation { router.tab = .splits } }
                    Button {
                        guard pro.allow(.races) else { return }
                        router.sheet = .race(Race(name: p.name, date: Calendar.current.date(byAdding: .day, value: 42, to: Date()) ?? Date(), plan: p))
                    } label: {
                        Image(systemName: "bookmark.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Track.tartan)
                            .frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Track.card))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Track.line))
                    }
                    .buttonStyle(Press())
                    .accessibilityLabel("Save as a race")
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
    }

    var distances: some View {
        let p = store.db.plan
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Distance.presets) { d in
                    let on = abs(p.meters - d.meters) < 1
                    Button { withAnimation(.spring(response: 0.35)) { store.setDistance(d) } } label: {
                        VStack(spacing: 1) {
                            Text(d.short).font(.sprint(17, .heavy))
                            Text(String(format: p.unit == .mi ? "%.1f mi" : "%.1f km", d.meters / p.unit.meters)).font(.body(10.5, .semibold)).opacity(0.7)
                        }
                        .foregroundStyle(on ? .white : Track.ink)
                        .padding(.horizontal, 14).frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Track.tartan : Track.card))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? .clear : Track.line))
                    }
                    .buttonStyle(Press())
                }
                HStack(spacing: 4) {
                    TextField("", text: $customKm, prompt: Text("Other").foregroundColor(Track.dim))
                        .keyboardType(.decimalPad).font(.sprint(16, .heavy)).foregroundStyle(Track.ink).frame(width: 58)
                        .onSubmit(applyCustom)
                    Text(p.unit.short).font(.body(12, .bold)).foregroundStyle(Track.dim)
                    Button(action: applyCustom) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Track.tartan) }.buttonStyle(.plain)
                }
                .padding(.horizontal, 12).frame(height: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Track.card))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Track.line))
            }
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: p.meters)
    }

    func applyCustom() {
        guard let v = Double(customKm.replacingOccurrences(of: ",", with: ".")), v > 0.1, v < 400 else { return }
        let m = v * store.db.plan.unit.meters
        store.setDistance(Distance(name: String(format: "%g %@", v, store.db.plan.unit.short), short: "", meters: m))
        customKm = ""
    }

    func paceCard(_ pace: TimeInterval) -> some View {
        let p = store.db.plan
        let other: Unit = p.unit == .mi ? .km : .mi
        let otherPace = pace / p.unit.meters * other.meters
        let speed = p.meters / p.goal * 3.6
        return VStack(alignment: .leading, spacing: 12) {
            LaneLabel("Pace")
            HStack(alignment: .center) {
                Button { nudge(-5) } label: { stepper("minus") }.buttonStyle(Press())
                Spacer()
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Fmt.pace(pace)).font(.sprint(58)).foregroundStyle(Track.ink).contentTransition(.numericText()).monospacedDigit()
                        Text("/\(p.unit.short)").font(.sprint(20, .heavy)).foregroundStyle(Track.tartan)
                    }
                    Text("5 seconds a tap").font(.body(11, .semibold)).foregroundStyle(Track.dim)
                }
                Spacer()
                Button { nudge(5) } label: { stepper("plus") }.buttonStyle(Press())
            }
            .sensoryFeedback(.selection, trigger: p.goal)
            HStack(spacing: 0) {
                mini("\(Fmt.pace(otherPace))", "per \(other.short)")
                Divider().frame(height: 30)
                mini(String(format: "%.1f", p.unit == .mi ? speed / 1.609344 : speed), p.unit == .mi ? "mph" : "km/h")
                Divider().frame(height: 30)
                mini(Fmt.pace(pace * 400 / p.unit.meters), "per 400 m lap")
            }
        }
        .card(16, radius: 24)
    }

    /// Faster or slower by 5 s per unit; the goal time follows.
    func nudge(_ s: Double) {
        let p = store.db.plan
        let units = p.meters / p.unit.meters
        let pace = (Pace.avgPace(p) / 5).rounded() * 5 + s
        withAnimation(.spring(response: 0.3)) { store.db.plan.goal = max(60, pace * units); store.db.plan.nudges = [] }
        store.save()
    }

    func stepper(_ icon: String) -> some View {
        Image(systemName: icon).font(.system(size: 18, weight: .black)).foregroundStyle(icon == "plus" ? .white : Track.ink)
            .frame(width: 50, height: 50).background(Circle().fill(icon == "plus" ? Track.ink : Track.paper2))
    }

    func mini(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.sprint(19, .heavy)).foregroundStyle(Track.ink).monospacedDigit()
            Text(l).font(.body(10.5, .semibold)).foregroundStyle(Track.dim)
        }
        .frame(maxWidth: .infinity)
    }

    /// What a few seconds per mile is worth over the whole race.
    func ladder(_ pace: TimeInterval) -> some View {
        let p = store.db.plan
        let units = p.meters / p.unit.meters
        let base = (pace / 5).rounded() * 5
        let steps: [Double] = [-15, -10, -5, 0, 5, 10, 15]
        return VStack(alignment: .leading, spacing: 10) {
            LaneLabel("If you ran", color: Track.infield)
            VStack(spacing: 0) {
                ForEach(steps, id: \.self) { d in
                    let pp = base + d, t = pp * units
                    let here = abs(t - p.goal) < 3
                    Button {
                        withAnimation(.spring(response: 0.3)) { store.db.plan.goal = t; store.db.plan.nudges = [] }
                        store.save()
                    } label: {
                        HStack {
                            Text("\(Fmt.pace(pp)) /\(p.unit.short)").font(.mono(15, here ? .bold : .medium)).foregroundStyle(here ? .white : Track.ink2)
                            Spacer()
                            Text(Fmt.clock(t)).font(.sprint(18, .heavy)).foregroundStyle(here ? .white : Track.ink).monospacedDigit()
                            Text(d == 0 ? "" : Fmt.delta(t - p.goal)).font(.mono(12)).foregroundStyle(here ? .white.opacity(0.7) : (d < 0 ? Track.ahead : Track.behind)).frame(width: 64, alignment: .trailing)
                        }
                        .padding(.horizontal, 14).frame(height: 42)
                        .background(here ? AnyView(Tartan()) : AnyView(Color.clear))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if d != steps.last { Rectangle().fill(Track.line).frame(height: 1) }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Track.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Track.line))
        }
    }
}

struct UnitToggle: View {
    @Environment(Store.self) private var store
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Unit.allCases, id: \.self) { u in
                let on = store.db.plan.unit == u
                Button { withAnimation(.spring(response: 0.3)) { store.db.plan.unit = u; store.db.plan.nudges = []; store.save() } } label: {
                    Text(u.short.uppercased()).font(.system(size: 12, weight: .heavy)).foregroundStyle(on ? .white : Track.ink2)
                        .frame(width: 42, height: 30).background(Capsule().fill(on ? Track.ink : .clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3).background(Capsule().fill(Track.paper2))
    }
}

/// Hours, minutes and seconds on three wheels.
struct TimeWheels: View {
    @Binding var seconds: TimeInterval
    var maxHours = 9
    var body: some View {
        let t = Int(seconds.rounded())
        HStack(spacing: 0) {
            wheel(0...maxHours, t / 3600, "h") { h in seconds = TimeInterval(h * 3600 + (t % 3600)) }
            wheel(0...59, (t % 3600) / 60, "m") { m in seconds = TimeInterval((t / 3600) * 3600 + m * 60 + t % 60) }
            wheel(0...59, t % 60, "s") { s in seconds = TimeInterval((t / 60) * 60 + s) }
        }
        .frame(height: 150)
    }
    func wheel(_ r: ClosedRange<Int>, _ v: Int, _ unit: String, _ set: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 0) {
            Picker("", selection: Binding(get: { v }, set: set)) {
                ForEach(Array(r), id: \.self) { Text(unit == "h" ? "\($0)" : String(format: "%02d", $0)).font(.sprint(24, .heavy)).tag($0) }
            }
            .pickerStyle(.wheel)
            Text(unit).font(.sprint(16, .heavy)).foregroundStyle(Track.tartan)
        }
        .frame(maxWidth: .infinity)
    }
}
