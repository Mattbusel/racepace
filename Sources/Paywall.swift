import SwiftUI

/// A finisher's medal on a striped ribbon, swinging gently.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var swing = false

    var body: some View {
        ZStack {
            PaperBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        LaneLabel("Race Pace Pro")
                        Spacer()
                        CloseKnob { dismiss() }
                    }
                    medal.rotationEffect(.degrees(swing ? 4 : -4), anchor: .top).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline).font(.sprint(32)).foregroundStyle(Track.ink).fixedSize(horizontal: false, vertical: true)
                        Text("The calculator, even splits and race predictions stay free. Pro is for the race you're training for.")
                            .font(.body(14.5)).foregroundStyle(Track.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        feature("stopwatch.fill", Track.led, "Race-day mode", "A finish clock in your hand: tap each marker and see how far ahead or behind plan you are.")
                        feature("chart.bar.xaxis", Track.tartan, "Split strategies", "Negative split, build, or nudge every split for the hills.")
                        feature("drop.fill", Track.sky, "Fueling plan", "Gels placed on your splits and called out on race day.")
                        feature("printer.fill", Track.ink, "Pace band and share card", "A printable wrist band and a goal card to post.")
                        feature("calendar", Track.infield, "Saved races", "Every race with its goal and plan, counting down the days.")
                    }
                    .card(18, radius: 26)
                    VStack(spacing: 4) {
                        Text(pro.price).font(.sprint(44)).foregroundStyle(Track.ink)
                        Text("ONCE · NO SUBSCRIPTION · FAMILY SHARING").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(Track.dim)
                    }
                    .frame(maxWidth: .infinity)
                    if let m = pro.message {
                        Text(m).font(.body(13, .semibold)).foregroundStyle(Track.behind).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                    BigButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill") { Task { await pro.buy() } }
                        .disabled(pro.busy)
                    HStack(spacing: 10) {
                        QuietButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        QuietButton(title: "Not now") { dismiss() }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) { swing = true } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .races: return "Every race, planned and counted down."
        case .strategy: return "Run the smart split."
        case .raceday: return "Know if you're on pace, mile by mile."
        case .fuel: return "Fuel on schedule, not on feel."
        case .band: return "Your splits on your wrist."
        case .settings: return "Race it, don't guess it."
        }
    }

    var medal: some View {
        VStack(spacing: -6) {
            // Ribbon: a V of track stripes.
            HStack(spacing: -10) {
                ribbon.rotationEffect(.degrees(18))
                ribbon.rotationEffect(.degrees(-18))
            }
            .frame(height: 110)
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xFFD66B), Color(hex: 0xE0A21E), Color(hex: 0xB9770E)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 150, height: 150)
                    .shadow(color: Color(hex: 0xB9770E).opacity(0.5), radius: 18, y: 10)
                Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 3).frame(width: 128, height: 128)
                VStack(spacing: 0) {
                    Image(systemName: "figure.run").font(.system(size: 34, weight: .bold)).foregroundStyle(Color(hex: 0x7A4E08))
                    Text("PRO").font(.sprint(30)).foregroundStyle(Color(hex: 0x7A4E08))
                    Text("FINISHER").font(.system(size: 9, weight: .heavy)).tracking(2).foregroundStyle(Color(hex: 0x7A4E08).opacity(0.8))
                }
            }
        }
    }

    var ribbon: some View {
        HStack(spacing: 0) {
            Track.tartan; Color.white.frame(width: 4); Track.tartan; Color.white.frame(width: 4); Track.tartan
        }
        .frame(width: 46, height: 120)
    }

    func feature(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(tint == Track.led ? Track.clock : tint)
                .frame(width: 40, height: 40).background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.opacity(0.16)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.sprint(16, .heavy)).foregroundStyle(Track.ink)
                Text(detail).font(.body(12.5)).foregroundStyle(Track.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        if pro.unlocked {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Track.ahead)
                Text("Race Pace Pro is unlocked. Run well.").font(.body(14.5, .bold)).foregroundStyle(Track.ink)
                Spacer()
            }
            .card(14, radius: 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Race Pace Pro").font(.sprint(20)).foregroundStyle(Track.ink)
                Text("Race-day mode, split strategies, fueling, the pace band and saved races. \(pro.price) once.").font(.body(12.5)).foregroundStyle(Track.dim)
                HStack(spacing: 10) {
                    QuietButton(title: "See Pro", icon: "sparkles", tint: Track.tartan) { pro.paywall = .settings }
                    QuietButton(title: "Restore", icon: "arrow.clockwise") { Task { await pro.restore() } }
                }
                if let m = pro.message, pro.paywall == nil { Text(m).font(.body(12, .semibold)).foregroundStyle(Track.behind) }
            }
            .card(16, radius: 22)
        }
    }
}
