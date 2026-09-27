import SwiftUI

/// Put in a recent race; see what it predicts for every other distance.
struct PredictView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var editing = false
    @State private var sources = false

    var body: some View {
        @Bindable var store = store
        let d1 = store.db.recentMeters, t1 = store.db.recentTime
        let unit = store.db.plan.unit
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Predict").font(.sprint(34)).foregroundStyle(Track.ink)
                    Text("From a race you ran recently, what the others should take").font(.body(13, .semibold)).foregroundStyle(Track.dim)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    LaneLabel("Your recent race")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Distance.presets) { d in
                                let on = abs(d1 - d.meters) < 1
                                Button {
                                    withAnimation(.spring(response: 0.35)) {
                                        store.db.recentTime = (store.db.recentTime / d1 * d.meters).rounded()
                                        store.db.recentMeters = d.meters
                                    }
                                    store.save()
                                } label: {
                                    Text(d.short).font(.sprint(16, .heavy)).foregroundStyle(on ? .white : Track.ink)
                                        .padding(.horizontal, 14).frame(height: 40)
                                        .background(Capsule().fill(on ? Track.ink : Track.paper2))
                                }
                                .buttonStyle(Press())
                            }
                        }
                    }
                    .scrollClipDisabled()
                    Button { withAnimation(.spring(response: 0.4)) { editing.toggle() } } label: {
                        HStack {
                            Text(Fmt.clock(t1)).font(.sprint(44)).foregroundStyle(Track.ink).monospacedDigit()
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Fmt.pace(t1 / (d1 / unit.meters)))/\(unit.short)").font(.mono(15, .bold)).foregroundStyle(Track.tartan)
                                Text(editing ? "Done" : "Change time").font(.body(12, .bold)).foregroundStyle(Track.dim)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    if editing {
                        TimeWheels(seconds: $store.db.recentTime, maxHours: 9).onChange(of: store.db.recentTime) { _, _ in store.save() }
                    }
                }
                .card(16, radius: 24)

                VStack(spacing: 10) {
                    ForEach(Distance.presets.filter { abs($0.meters - d1) > 1 }) { d in
                        let t = Pace.riegel(from: t1, meters: d1, to: d.meters)
                        PredictionRow(distance: d, time: t, unit: unit) {
                            store.setDistance(d)
                            store.db.plan.goal = (t / 5).rounded() * 5
                            store.db.plan.nudges = []
                            store.save()
                            withAnimation { router.tab = .pace }
                        }
                    }
                }

                Text("Predictions use Riegel's endurance formula, which assumes you've trained for the distance. For a first marathon, most runners come in slower than predicted.")
                    .font(.body(12)).foregroundStyle(Track.dim).fixedSize(horizontal: false, vertical: true)
                Button { sources = true } label: { Label("Sources", systemImage: "book.closed").font(.body(12.5, .bold)).foregroundStyle(Track.sky) }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
        .sheet(isPresented: $sources) { SourcesView().presentationBackground(Track.paper) }
    }
}

struct PredictionRow: View {
    let distance: Distance
    let time: TimeInterval
    let unit: Unit
    let use: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Tartan(lanes: 0)
                VStack(spacing: 0) {
                    Text(distance.short).font(.sprint(20)).foregroundStyle(.white)
                    Text(String(format: "%.1f %@", distance.meters / unit.meters, unit.short)).font(.body(10, .bold)).foregroundStyle(.white.opacity(0.75))
                }
            }
            .frame(width: 84)
            .overlay(alignment: .trailing) { Rectangle().fill(.white).frame(width: 3) }
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.clock(time)).font(.sprint(28)).foregroundStyle(Track.ink).monospacedDigit()
                Text("\(Fmt.pace(time / (distance.meters / unit.meters)))/\(unit.short)").font(.mono(13, .semibold)).foregroundStyle(Track.dim)
            }
            .padding(.leading, 14)
            Spacer()
            Button(action: use) {
                Text("Make it\nmy goal").font(.body(11.5, .bold)).multilineTextAlignment(.center).foregroundStyle(Track.tartan)
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Track.tartan.opacity(0.1)))
            }
            .buttonStyle(Press())
            .padding(.trailing, 12)
        }
        .frame(height: 76)
        .background(Track.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Track.line))
        .shadow(color: Color(hex: 0x5A3A20, alpha: 0.08), radius: 8, y: 4)
    }
}

// MARK: - Races

/// Saved races with a countdown (Pro).
struct RacesView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Races").font(.sprint(34)).foregroundStyle(Track.ink)
                    Spacer()
                    Button {
                        guard pro.allow(.races) else { return }
                        router.sheet = .race(Race(name: store.db.plan.name, date: Calendar.current.date(byAdding: .day, value: 42, to: Date()) ?? Date(), plan: store.db.plan))
                    } label: {
                        Label("Add", systemImage: "plus").font(.body(14, .heavy)).foregroundStyle(.white)
                            .padding(.horizontal, 14).frame(height: 36).background(Capsule().fill(Track.tartan))
                    }
                    .buttonStyle(Press())
                }
                .padding(.top, 8)
                if store.db.races.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "flag.checkered.2.crossed").font(.system(size: 28, weight: .bold)).foregroundStyle(Track.tartan)
                        Text("Your race calendar").font(.sprint(22)).foregroundStyle(Track.ink)
                        Text("Save each race with its goal, strategy and fueling, count down the days, and load it into race-day mode on the morning.")
                            .font(.body(13.5)).foregroundStyle(Track.dim).fixedSize(horizontal: false, vertical: true)
                        if !pro.unlocked { ProBadge() }
                    }
                    .card(18, radius: 24)
                }
                let upcoming = store.db.races.filter { $0.date >= Calendar.current.startOfDay(for: Date()) }
                let past = store.db.races.filter { $0.date < Calendar.current.startOfDay(for: Date()) }.reversed()
                ForEach(upcoming) { r in RaceCard(race: r) }
                if !past.isEmpty {
                    LaneLabel("Done", color: Track.dim).padding(.top, 6)
                    ForEach(Array(past)) { r in RaceCard(race: r) }
                }
                ProCard().padding(.top, 8)
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
    }
}

struct RaceCard: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let race: Race
    var body: some View {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: race.date)).day ?? 0
        Button { router.sheet = .race(race) } label: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Text(days >= 0 ? "\(days)" : "✓").font(.sprint(34)).foregroundStyle(Track.led).monospacedDigit()
                    Text(days >= 0 ? (days == 1 ? "DAY" : "DAYS") : "RAN").font(.system(size: 10, weight: .heavy)).tracking(1.5).foregroundStyle(.white.opacity(0.6))
                }
                .frame(width: 88).frame(maxHeight: .infinity)
                .background(Track.clock)
                VStack(alignment: .leading, spacing: 4) {
                    Text(race.name).font(.sprint(19, .heavy)).foregroundStyle(Track.ink).lineLimit(1)
                    Text(Fmt.day(race.date)).font(.body(12.5, .semibold)).foregroundStyle(Track.dim)
                    HStack(spacing: 8) {
                        Text("Goal \(Fmt.clock(race.plan.goal))").font(.mono(13, .bold)).foregroundStyle(Track.tartan)
                        if let r = race.result { Text("Ran \(Fmt.clock(r))").font(.mono(13, .bold)).foregroundStyle(r <= race.plan.goal ? Track.ahead : Track.ink2) }
                    }
                }
                .padding(.horizontal, 14)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Track.dim).padding(.trailing, 14)
            }
            .frame(height: 92)
            .background(Track.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Track.line))
        }
        .buttonStyle(Press())
    }
}

struct RaceEditor: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State var race: Race
    @State private var ran = false

    var body: some View {
        let exists = store.db.races.contains(where: { $0.id == race.id })
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(exists ? "Race" : "Save race").font(.sprint(28)).foregroundStyle(Track.ink)
                    Spacer()
                    CloseKnob { dismiss() }
                }
                .padding(.top, 24)
                VStack(alignment: .leading, spacing: 8) {
                    LaneLabel("Name")
                    TextField("", text: $race.name, prompt: Text("City Half Marathon").foregroundColor(Track.dim))
                        .font(.sprint(20, .heavy)).foregroundStyle(Track.ink).padding(.horizontal, 14).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Track.card))
                }
                DatePicker("Race day", selection: $race.date, displayedComponents: .date).font(.body(15, .bold)).foregroundStyle(Track.ink).tint(Track.tartan)
                    .padding(.horizontal, 14).frame(height: 52).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Track.card))
                HStack(spacing: 10) {
                    info("Distance", String(format: "%.2f %@", race.plan.meters / race.plan.unit.meters, race.plan.unit.short))
                    info("Goal", Fmt.clock(race.plan.goal))
                    info("Plan", race.plan.strategy.title)
                }
                if race.date < Date() || ran {
                    VStack(alignment: .leading, spacing: 8) {
                        LaneLabel("Your result", color: Track.ahead)
                        TimeWheels(seconds: Binding(get: { race.result ?? race.plan.goal }, set: { race.result = $0 })).card(6, radius: 18)
                    }
                } else {
                    QuietButton(title: "I ran it: add my time", icon: "flag.checkered") { withAnimation { ran = true } }
                }
                BigButton(title: "Save", icon: "checkmark") { store.upsert(race); dismiss() }
                if exists {
                    QuietButton(title: "Load into the calculator", icon: "arrow.down.circle") {
                        store.db.plan = race.plan; store.save(); dismiss(); withAnimation { router.tab = .splits }
                    }
                    QuietButton(title: "Delete race", icon: "trash", tint: Track.behind) { store.remove(race); dismiss() }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
    }

    func info(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l.uppercased()).font(.system(size: 9.5, weight: .heavy)).tracking(1.2).foregroundStyle(Track.dim)
            Text(v).font(.sprint(16, .heavy)).foregroundStyle(Track.ink).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(12, radius: 16)
    }
}
