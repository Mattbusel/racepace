import SwiftUI
import UIKit

/// Race-day mode: a finish clock in your hand. Tap the big button at each marker and see,
/// in seconds, whether you're ahead of plan or behind it (Pro).
struct RaceDayView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var confirmStop = false
    @State private var tick = 0

    var body: some View {
        let p = store.db.plan
        let splits = store.splits
        ZStack {
            Color.black.ignoresSafeArea()
            Tartan(lanes: 8).opacity(0.14).ignoresSafeArea()
            VStack(spacing: 0) {
                top(p)
                if let run = store.run {
                    TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                        running(run, splits: splits, plan: p, now: store.demo ? run.start.addingTimeInterval(58 * 60 + 41) : ctx.date)
                    }
                } else {
                    ready(p, splits: splits)
                }
            }
            .padding(.horizontal, 18)
        }
        .preferredColorScheme(.dark)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sensoryFeedback(.impact(weight: .heavy), trigger: tick)
        .confirmationDialog("Stop the race clock?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Stop and clear", role: .destructive) { store.run = nil; store.save(); dismiss() }
            Button("Leave it running", role: .cancel) { dismiss() }
        } message: { Text("You can leave race-day mode and come back; the clock keeps running.") }
    }

    func top(_ p: Plan) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("RACE DAY").font(.system(size: 11, weight: .heavy)).tracking(2).foregroundStyle(Track.led)
                Text("\(p.name) · goal \(Fmt.clock(p.goal))").font(.sprint(17, .heavy)).foregroundStyle(.white)
            }
            Spacer()
            CloseKnob(dark: true) { if store.run != nil { confirmStop = true } else { dismiss() } }
        }
        .padding(.top, 12)
    }

    func ready(_ p: Plan, splits: [Split]) -> some View {
        VStack(spacing: 24) {
            Spacer()
            SevenSeg(text: Fmt.clock(0, forceHours: p.goal >= 3600), height: 80, on: Track.led.opacity(0.35))
            Text("Tap GO when you cross the start mat.\nThen tap once at every \(p.unit.name) marker.").font(.body(15, .semibold)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            Spacer()
            Button {
                store.run = RaceRun(start: Date()); store.save(); tick += 1
            } label: {
                Text("GO").font(.sprint(64)).foregroundStyle(.black)
                    .frame(width: 210, height: 210)
                    .background(Circle().fill(Track.ahead).shadow(color: Track.ahead.opacity(0.6), radius: 30))
            }
            .buttonStyle(Press())
            Spacer()
        }
    }

    func running(_ run: RaceRun, splits: [Split], plan: Plan, now: Date) -> some View {
        let elapsed = now.timeIntervalSince(run.start)
        let done = run.laps.count
        let finished = done >= splits.count
        let last = done > 0 ? run.laps[done - 1].timeIntervalSince(run.start) : nil
        let lastPlan = done > 0 ? splits[min(done, splits.count) - 1].at : nil
        let delta = (last != nil && lastPlan != nil) ? last! - lastPlan! : nil
        let next = finished ? nil : splits[done]
        let gel = Pace.gels(plan).first { elapsed >= $0 - 30 && elapsed <= $0 + 120 }
        return VStack(spacing: 18) {
            FinishClock(time: Fmt.clock(elapsed, forceHours: plan.goal >= 3600), caption: finished ? "Finished" : "Elapsed", height: 70)
                .padding(.top, 18)
            if let delta {
                VStack(spacing: 2) {
                    Text(delta <= 0 ? "AHEAD" : "BEHIND").font(.system(size: 13, weight: .heavy)).tracking(3).foregroundStyle(delta <= 0 ? Track.ahead : Track.behind)
                    Text(Fmt.delta(delta)).font(.sprint(64)).foregroundStyle(delta <= 0 ? Track.ahead : Track.behind).monospacedDigit()
                    Text("at \(plan.unit.name) \(splits[done - 1].label), against a plan of \(Fmt.clock(splits[done - 1].at))").font(.body(13, .semibold)).foregroundStyle(.white.opacity(0.55))
                }
            } else {
                Text("Tap at your first \(plan.unit.name) marker").font(.body(15, .semibold)).foregroundStyle(.white.opacity(0.6)).padding(.vertical, 30)
            }
            if let gel {
                HStack(spacing: 10) {
                    Image(systemName: "drop.fill").font(.system(size: 18, weight: .bold))
                    Text("Gel and water now (\(Fmt.clock(gel)))").font(.sprint(18, .heavy))
                }
                .foregroundStyle(.white).padding(.horizontal, 18).frame(height: 48)
                .background(Capsule().fill(Track.sky))
                .transition(.scale.combined(with: .opacity))
            }
            Spacer(minLength: 0)
            CourseStrip(splits: splits, laps: run.laps.map { $0.timeIntervalSince(run.start) }, elapsed: elapsed, unit: plan.unit)
            Spacer(minLength: 0)
            if let next {
                let togo = run.start.addingTimeInterval(next.at).timeIntervalSince(now)
                VStack(spacing: 6) {
                    HStack {
                        Text("NEXT: \(plan.unit.name.uppercased()) \(next.label)").font(.system(size: 12, weight: .heavy)).tracking(1.5).foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Text("due at \(Fmt.clock(next.at)) · pace \(Fmt.pace(next.pace))").font(.mono(12.5, .bold)).foregroundStyle(.white.opacity(0.75))
                    }
                    Button {
                        var r = run; r.laps.append(Date()); store.run = r; store.save(); tick += 1
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(plan.unit.name.uppercased()) \(next.label)").font(.sprint(46)).foregroundStyle(.black)
                            Text(togo >= 0 ? "Tap as you pass the marker · \(Fmt.clock(togo)) to plan" : "Tap as you pass the marker · \(Fmt.clock(-togo)) past plan")
                                .font(.body(13, .bold)).foregroundStyle(.black.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity).frame(height: 170)
                        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Track.led).shadow(color: Track.led.opacity(0.4), radius: 24))
                    }
                    .buttonStyle(Press())
                    if done > 0 {
                        Button { var r = run; r.laps.removeLast(); store.run = r; store.save() } label: {
                            Label("Undo last tap", systemImage: "arrow.uturn.backward").font(.body(13, .bold)).foregroundStyle(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain).padding(.top, 4)
                    }
                }
                .padding(.bottom, 20)
            } else {
                VStack(spacing: 10) {
                    Text(elapsed <= plan.goal ? "Goal smashed." : "Done. Every split counted.").font(.sprint(30)).foregroundStyle(.white)
                    BigButton(title: "Finish and close", icon: "flag.checkered", color: Track.ahead) { store.run = nil; store.save(); dismiss() }
                }
                .padding(.bottom, 24)
            }
        }
        .animation(.spring(response: 0.4), value: done)
    }
}

/// The course as one lane: the pacer (where the plan says you are) and you (from your last marker).
struct CourseStrip: View {
    let splits: [Split]
    let laps: [TimeInterval]
    let elapsed: TimeInterval
    let unit: Unit
    var body: some View {
        let total = max(0.01, splits.reduce(0) { $0 + $1.length })
        let pacer = min(total, Pace.position(splits, at: elapsed))
        // You: the last marker you passed, then moving on at the plan's pace for the next split.
        let doneUnits = splits.prefix(laps.count).reduce(0) { $0 + $1.length }
        let since = elapsed - (laps.last ?? 0)
        let nextPace = laps.count < splits.count ? splits[laps.count].pace : 1
        let you = min(total, doneUnits + max(0, since) / nextPace)
        VStack(spacing: 8) {
            GeometryReader { g in
                let W = g.size.width
                ZStack(alignment: .leading) {
                    Tartan().clipShape(Capsule())
                    Capsule().fill(.white.opacity(0.85)).frame(height: 2).padding(.horizontal, 10)
                    ForEach(1..<max(2, splits.count), id: \.self) { i in
                        Rectangle().fill(.white.opacity(0.35)).frame(width: 1.5, height: 14)
                            .offset(x: W * CGFloat(splits.prefix(i).reduce(0) { $0 + $1.length } / total))
                    }
                    marker("PACER", Color.white, x: W * CGFloat(pacer / total)).offset(y: -18)
                    marker("YOU", Track.led, x: W * CGFloat(you / total)).offset(y: 18)
                }
            }
            .frame(height: 30)
            HStack {
                Text("START").font(.system(size: 10, weight: .heavy)).tracking(1.2)
                Spacer()
                Text(String(format: "%.1f of %.1f ", you, total) + unit.short).font(.mono(12, .bold))
                Spacer()
                Text("FINISH").font(.system(size: 10, weight: .heavy)).tracking(1.2)
            }
            .foregroundStyle(.white.opacity(0.55))
            .padding(.top, 14)
        }
        .padding(.vertical, 20)
    }

    func marker(_ label: String, _ c: Color, x: CGFloat) -> some View {
        VStack(spacing: 2) {
            if label == "PACER" { Text(label).font(.system(size: 8.5, weight: .heavy)).foregroundStyle(c) }
            Circle().fill(c).frame(width: 14, height: 14).overlay(Circle().strokeBorder(.black, lineWidth: 2))
            if label == "YOU" { Text(label).font(.system(size: 8.5, weight: .heavy)).foregroundStyle(c) }
        }
        .offset(x: x - 7)
    }
}
