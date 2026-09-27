import SwiftUI

@main
struct RacePaceApp: App {
    @State private var store: Store
    @State private var router = Router()
    @State private var pro: Pro

    init() {
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay")
        _store = State(initialValue: Store(demo: demo))
        let shot = a.firstIndex(of: "-shot").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
        let p: Pro
        if shot == "paywall" { p = Pro(forced: false); p.paywall = .raceday }
        else if demo { p = Pro(forced: true) }
        else { p = Pro() }
        _pro = State(initialValue: p)
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(router).environment(pro)
                .preferredColorScheme(.light).tint(Track.tartan)
                .onAppear { router.applyShotArgs(store); Autopilot.shared.run(store, router, pro) }
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case pace, splits, predict, races
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var lane: Int { (Tab.allCases.firstIndex(of: self) ?? 0) + 1 }
}

enum Sheet: Identifiable {
    case strategy, band, race(Race)
    var id: String {
        switch self {
        case .strategy: return "strategy"
        case .band: return "band"
        case .race(let r): return "race-\(r.id)"
        }
    }
}

@MainActor
@Observable
final class Router {
    var tab: Tab = .pace
    var sheet: Sheet? = nil
    var raceDay = false

    func applyShotArgs(_ s: Store) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        switch a[i + 1] {
        case "splits": tab = .splits
        case "strategy": tab = .splits; sheet = .strategy
        case "predict": tab = .predict
        case "band": tab = .splits; sheet = .band
        case "raceday": s.run = Demo.run(s); raceDay = true
        default: break
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        @Bindable var router = router
        @Bindable var pro = pro
        ZStack(alignment: .bottom) {
            PaperBackground()
            Group {
                switch router.tab {
                case .pace: PaceView()
                case .splits: SplitsView()
                case .predict: PredictView()
                case .races: RacesView()
                }
            }
            .transition(.opacity)
            LaneBar(selection: $router.tab) {
                if pro.allow(.raceday) { router.raceDay = true }
            }
        }
        .sheet(item: $router.sheet) { sheet in
            Group {
                switch sheet {
                case .strategy: StrategySheet()
                case .band: BandSheet()
                case .race(let r): RaceEditor(race: r)
                }
            }
            .presentationBackground(Track.paper).presentationCornerRadius(30)
            .environment(store).environment(router).environment(pro)
        }
        .fullScreenCover(isPresented: $router.raceDay) {
            RaceDayView().environment(store).environment(router).environment(pro)
        }
        .overlay {
            Color.clear.allowsHitTesting(false)
                .sheet(item: $pro.paywall) { why in
                    PaywallView(reason: why).environment(pro).presentationBackground(Track.paper).presentationCornerRadius(30)
                }
        }
    }
}

/// The tab bar is four lanes of track, numbered like the start line; the chosen lane gets
/// the white box. The round button in the middle is the start: race-day mode.
struct LaneBar: View {
    @Binding var selection: Tab
    var go: () -> Void
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            item(.pace); item(.splits)
            Button(action: go) {
                ZStack {
                    Circle().fill(Track.clock).frame(width: 66, height: 66)
                        .overlay(Circle().strokeBorder(Track.led.opacity(0.6), lineWidth: 2))
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
                    VStack(spacing: 0) {
                        Image(systemName: "stopwatch.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(Track.led)
                        Text("GO").font(.sprint(11)).foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(Press())
            .offset(y: -14)
            .frame(width: 84)
            .accessibilityLabel("Race day mode")
            item(.predict); item(.races)
        }
        .padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 2)
        .background(alignment: .top) {
            Tartan(lanes: 0)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.9)).frame(height: 3) }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous))
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: Track.tartanDeep.opacity(0.35), radius: 16, y: -2)
        }
    }

    func item(_ t: Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = t }
        } label: {
            VStack(spacing: 3) {
                Text("\(t.lane)").font(.sprint(22)).foregroundStyle(selection == t ? Track.tartan : .white)
                    .frame(width: 36, height: 32)
                    .background {
                        if selection == t { RoundedRectangle(cornerRadius: 6).fill(.white).matchedGeometryEffect(id: "lane", in: ns) }
                    }
                Text(t.title.uppercased()).font(.system(size: 9.5, weight: .heavy)).tracking(1.2).foregroundStyle(.white.opacity(selection == t ? 1 : 0.7))
            }
            .frame(maxWidth: .infinity).frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
