import SwiftUI

/// Drives the real screens for the App Review recording (-demoAutoplay).
@MainActor
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private var running = false
    private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    func run(_ store: Store, _ router: Router, _ pro: Pro) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(4)
            for _ in 0..<3 {
                withAnimation { store.db.plan.goal -= 5 * 13.1 }; await wait(0.8)
            }
            await wait(1.5)
            withAnimation { router.tab = .splits }; await wait(4)
            router.sheet = .strategy; await wait(4.5)
            router.sheet = nil; await wait(1.2)
            router.sheet = .band; await wait(4)
            router.sheet = nil; await wait(1.2)
            withAnimation { router.tab = .predict }; await wait(4)
            withAnimation { router.tab = .races }; await wait(3.5)
            store.run = Demo.run(store); router.raceDay = true; await wait(5)
            router.raceDay = false; await wait(1.5)
            withAnimation { router.tab = .pace }; await wait(1)
            pro.paywall = .settings; await wait(5)
            pro.paywall = nil; await wait(1.5)
            try? Data("ok".utf8).write(to: URL.documentsDirectory.appending(path: "demo_done"))
        }
    }
}
