import SwiftUI

/// The pace band: a printable wrist strip with the clock time at every marker, and a share card (Pro).
struct BandSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let p = store.db.plan
        let splits = store.splits
        let gels = Pace.gels(p)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Pace band").font(.sprint(30)).foregroundStyle(Track.ink)
                    Spacer()
                    CloseKnob { dismiss() }
                }
                .padding(.top, 24)
                HStack(alignment: .top, spacing: 18) {
                    PaceBand(plan: p, splits: splits, gels: gels, scale: 1.25)
                        .rotationEffect(.degrees(-2))
                        .shadow(color: .black.opacity(0.2), radius: 14, x: 4, y: 10)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Print it, cut it out, wrap it round your wrist with clear tape.").font(.body(14, .semibold)).foregroundStyle(Track.ink2).fixedSize(horizontal: false, vertical: true)
                        Text("Each line is the clock time you should see as you pass that \(p.unit.name) marker.").font(.body(13)).foregroundStyle(Track.dim).fixedSize(horizontal: false, vertical: true)
                        if !gels.isEmpty { Label("Drops mark your gels", systemImage: "drop.fill").font(.body(12.5, .bold)).foregroundStyle(Track.sky) }
                        ShareLink(item: BandPDF.make(plan: p, splits: splits, gels: gels), preview: SharePreview("\(p.name) pace band")) {
                            Label("Print or save PDF", systemImage: "printer.fill").font(.body(14, .heavy)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 48).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Track.ink))
                        }
                        if let card = ShareCard.image(plan: p) {
                            ShareLink(item: Image(uiImage: card), preview: SharePreview("\(p.name) goal", image: Image(uiImage: card))) {
                                Label("Share goal card", systemImage: "square.and.arrow.up").font(.body(14, .heavy)).foregroundStyle(Track.tartan)
                                    .frame(maxWidth: .infinity).frame(height: 48).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Track.tartan.opacity(0.1)))
                            }
                        }
                    }
                }
                if let card = ShareCard.image(plan: p) {
                    VStack(alignment: .leading, spacing: 10) {
                        LaneLabel("Goal card")
                        Image(uiImage: card).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
    }
}

/// The band itself: a tartan header, then one row per marker.
struct PaceBand: View {
    let plan: Plan
    let splits: [Split]
    let gels: [TimeInterval]
    var scale: CGFloat = 1
    var body: some View {
        let row: CGFloat = splits.count > 20 ? 15 : 18
        VStack(spacing: 0) {
            ZStack {
                Tartan()
                VStack(spacing: 0) {
                    Text(plan.name.uppercased()).font(.system(size: 7.5, weight: .black)).italic().foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                    Text(Fmt.clock(plan.goal)).font(.system(size: 15, weight: .black)).italic().foregroundStyle(.white).monospacedDigit()
                    Text("\(Fmt.pace(Pace.avgPace(plan)))/\(plan.unit.short)").font(.system(size: 7.5, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 50)
            ForEach(splits) { s in
                let gel = gels.contains { $0 > s.at - s.time && $0 <= s.at }
                HStack(spacing: 2) {
                    Text(s.label).font(.system(size: 8.5, weight: .black)).italic().foregroundStyle(Track.tartan).lineLimit(1).minimumScaleFactor(0.7).frame(width: 26, alignment: .leading)
                    if gel { Image(systemName: "drop.fill").font(.system(size: 6.5)).foregroundStyle(Track.sky) }
                    Spacer(minLength: 0)
                    Text(Fmt.clock(s.at)).font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(Track.ink)
                }
                .padding(.horizontal, 6).frame(height: row)
                .background(s.id % 2 == 0 ? Color.white : Track.paper2.opacity(0.6))
            }
        }
        .frame(width: 88)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Track.ink.opacity(0.2)))
        .scaleEffect(scale, anchor: .top)
        .frame(width: 88 * scale, height: (50 + CGFloat(splits.count) * row) * scale, alignment: .top)
    }
}

enum BandPDF {
    /// US Letter, the band at true size (about 1.2 in wide) with a dashed cut line, twice.
    @MainActor static func make(plan: Plan, splits: [Split], gels: [TimeInterval]) -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(plan.name.replacingOccurrences(of: " ", with: "-"))-pace-band.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return url }
        let page = ZStack(alignment: .topLeading) {
            Color.white
            VStack(alignment: .leading, spacing: 10) {
                Text("\(plan.name) · goal \(Fmt.clock(plan.goal)) · \(plan.strategy.title.lowercased())").font(.system(size: 13, weight: .bold))
                Text("Cut along the dashed lines. Wrap around your wrist, clock times facing you, and cover with clear tape.").font(.system(size: 10))
                HStack(alignment: .top, spacing: 40) {
                    ForEach(0..<2, id: \.self) { _ in
                        PaceBand(plan: plan, splits: splits, gels: gels, scale: 1.3)
                            .padding(8)
                            .overlay(Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 0.8, dash: [4, 3])).foregroundStyle(.gray))
                    }
                }
                .padding(.top, 10)
            }
            .padding(40)
        }
        .frame(width: 612, height: 792)
        let r = ImageRenderer(content: page)
        r.render { _, draw in
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return url
    }
}

/// A square card for socials: the goal on a finish clock over tartan.
enum ShareCard {
    @MainActor static func image(plan: Plan) -> UIImage? {
        let v = ZStack {
            Tartan(lanes: 6)
            VStack(spacing: 18) {
                Text(plan.name.uppercased()).font(.system(size: 34, weight: .black)).italic().foregroundStyle(.white)
                FinishClock(time: Fmt.clock(plan.goal, forceHours: plan.goal >= 3600), caption: "Goal", height: 84).padding(.horizontal, 40)
                Text("\(Fmt.pace(Pace.avgPace(plan))) per \(plan.unit.name) · \(plan.strategy.title.lowercased())").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                Text("RACE PACE").font(.system(size: 14, weight: .black)).italic().tracking(3).foregroundStyle(.white.opacity(0.7)).padding(.top, 10)
            }
        }
        .frame(width: 540, height: 540)
        let r = ImageRenderer(content: v)
        r.scale = 2
        return r.uiImage
    }
}
