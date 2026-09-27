import SwiftUI
import StoreKit

/// Race Pace Pro: one non-consumable. The calculator, even splits and the predictor are free
/// forever. Pro adds saved races, split strategies, fueling, the pace band and race-day mode.
@MainActor
@Observable
final class Pro {
    static let productID = "com.mattbusel.racepace.pro"
    enum Reason: String, Identifiable { case races, strategy, raceday, fuel, band, settings; var id: String { rawValue } }

    private(set) var unlocked: Bool
    private(set) var product: Product?
    var busy = false
    var message: String?
    var paywall: Reason? = nil

    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let key = "racepace.pro.unlocked"
    @ObservationIgnored private let forced: Bool

    /// `forced` is for screenshots and the review recording, which must not touch StoreKit.
    init(forced: Bool? = nil) {
        self.forced = forced != nil
        if let forced { unlocked = forced; return }
        unlocked = UserDefaults.standard.bool(forKey: key)
        updates = Task { [weak self] in
            for await result in Transaction.updates { await self?.apply(result) }
        }
        Task { await refresh() }
    }

    var price: String { product?.displayPrice ?? "$3.99" }

    /// True when the action may go ahead; otherwise shows the paywall.
    @discardableResult
    func allow(_ why: Reason) -> Bool {
        if unlocked { return true }
        paywall = why
        return false
    }

    func refresh() async {
        guard !forced else { return }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        for await result in Transaction.currentEntitlements { await apply(result) }
    }

    func buy() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        if product == nil { product = try? await Product.products(for: [Pro.productID]).first }
        guard let product else {
            message = "The App Store did not answer. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
                if !unlocked { message = "Apple could not confirm the purchase. Try Restore in a minute." }
            case .pending:
                message = "Waiting for approval. Pro unlocks by itself once it is approved."
            case .userCancelled:
                break
            @unknown default:
                message = "Something unexpected happened. You were not charged."
            }
        } catch {
            message = "The purchase did not go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !forced, !busy else { return }
        busy = true; message = nil
        defer { busy = false }
        do { try await AppStore.sync() } catch {
            if let e = error as? StoreKitError, case .userCancelled = e { return }
            message = "Could not reach the App Store. Check your connection and try again."
            return
        }
        await refresh()
        message = unlocked ? "Pro is unlocked. Welcome back." : "No Pro purchase found on this Apple ID."
    }

    private func apply(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let t) = result, t.productID == Pro.productID else { return }
        if t.revocationDate == nil { grant() } else { revoke() }
        await t.finish()
    }

    private func grant() {
        guard !unlocked else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { unlocked = true }
        paywall = nil
        UserDefaults.standard.set(true, forKey: key)
    }

    private func revoke() {
        unlocked = false
        UserDefaults.standard.set(false, forKey: key)
    }
}

