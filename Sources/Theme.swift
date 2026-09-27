import SwiftUI
import UIKit

/// Race Pace's look: an athletics track. Tartan red with painted white lane lines, the
/// infield green, chalk-white paper, and the finish-line clock in amber LED segments.
enum Track {
    static let paper = Color(hex: 0xF4EFE6)
    static let paper2 = Color(hex: 0xEAE3D6)
    static let card = Color(hex: 0xFFFDF8)
    static let tartan = Color(hex: 0xC8472B)
    static let tartanDeep = Color(hex: 0xA5391F)
    static let infield = Color(hex: 0x3E8E5A)
    static let ink = Color(hex: 0x1D1A17)
    static let ink2 = Color(hex: 0x4D463F)
    static let dim = Color(hex: 0x8B8177)
    static let line = Color(hex: 0x1D1A17, alpha: 0.08)
    static let clock = Color(hex: 0x121212)
    static let led = Color(hex: 0xFFB020)
    static let ahead = Color(hex: 0x2FA866)
    static let behind = Color(hex: 0xE0442B)
    static let sky = Color(hex: 0x2F6FD6)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
}

extension Font {
    /// Heavy italic: the bib number and the track-meet poster.
    static func sprint(_ size: CGFloat, _ weight: Font.Weight = .black) -> Font { .system(size: size, weight: weight).italic() }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight) }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}

// MARK: - Surfaces

/// Tartan: the red track surface with its fine rubber grain.
struct Tartan: View {
    var lanes = 0
    var body: some View {
        ZStack {
            LinearGradient(colors: [Track.tartan, Track.tartanDeep], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                var seed: UInt64 = 0x7A57
                func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
                for _ in 0..<Int(size.width * size.height / 70) {
                    let x = rnd() * size.width, y = rnd() * size.height
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.3)), with: .color(rnd() > 0.5 ? .white.opacity(0.07) : .black.opacity(0.1)))
                }
                if lanes > 0 {
                    for i in 1..<lanes {
                        let y = size.height * CGFloat(i) / CGFloat(lanes)
                        ctx.fill(Path(CGRect(x: 0, y: y - 1.2, width: size.width, height: 2.4)), with: .color(.white.opacity(0.9)))
                    }
                }
            }
        }
    }
}

/// Paper with a faint lane-line texture.
struct PaperBackground: View {
    var body: some View {
        ZStack {
            Track.paper
            Canvas { ctx, size in
                var seed: UInt64 = 3
                func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
                for _ in 0..<Int(size.width * size.height / 300) {
                    ctx.fill(Path(ellipseIn: CGRect(x: rnd() * size.width, y: rnd() * size.height, width: 1, height: 1)), with: .color(.black.opacity(0.05)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct CardStyle: ViewModifier {
    var pad: CGFloat = 16
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content.padding(pad)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Track.card).shadow(color: Color(hex: 0x5A3A20, alpha: 0.1), radius: 12, y: 5))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Track.line))
    }
}
extension View {
    func card(_ pad: CGFloat = 16, radius: CGFloat = 22) -> some View { modifier(CardStyle(pad: pad, radius: radius)) }
}

/// A section label painted like a lane marking.
struct LaneLabel: View {
    let text: String
    var color: Color = Track.tartan
    init(_ text: String, color: Color = Track.tartan) { self.text = text; self.color = color }
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(color).frame(width: 14, height: 3)
            Text(text.uppercased()).font(.system(size: 11.5, weight: .heavy)).tracking(1.8).foregroundStyle(color)
        }
    }
}

struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct BigButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Track.tartan
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .heavy)) }
                Text(title).font(.sprint(18, .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color).shadow(color: color.opacity(0.35), radius: 12, y: 6))
        }
        .buttonStyle(Press())
    }
}

struct QuietButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Track.ink
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title).font(.body(15, .bold))
            }
            .foregroundStyle(tint).frame(maxWidth: .infinity).frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Track.paper2))
        }
        .buttonStyle(Press())
    }
}

struct CloseKnob: View {
    var dark = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(dark ? .white : Track.ink2)
                .frame(width: 36, height: 36).background(Circle().fill(dark ? Color.white.opacity(0.14) : Track.paper2))
        }
        .buttonStyle(Press())
        .accessibilityLabel("Close")
    }
}

// MARK: - The finish clock

/// Seven-segment LED digits, the way a finish-line clock shows time.
struct SevenSeg: View {
    let text: String
    var height: CGFloat = 64
    var on: Color = Track.led
    var off: Color = Color.white.opacity(0.06)

    static let map: [Character: [Bool]] = [
        // a, b, c, d, e, f, g
        "0": [true, true, true, true, true, true, false], "1": [false, true, true, false, false, false, false],
        "2": [true, true, false, true, true, false, true], "3": [true, true, true, true, false, false, true],
        "4": [false, true, true, false, false, true, true], "5": [true, false, true, true, false, true, true],
        "6": [true, false, true, true, true, true, true], "7": [true, true, true, false, false, false, false],
        "8": [true, true, true, true, true, true, true], "9": [true, true, true, true, false, true, true],
        "-": [false, false, false, false, false, false, true], " ": [false, false, false, false, false, false, false],
    ]

    var body: some View {
        let w = height * 0.52, t = height * 0.11
        HStack(spacing: height * 0.1) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                if ch == ":" || ch == "." {
                    VStack(spacing: height * 0.28) {
                        if ch == ":" { dot(t) }
                        dot(t)
                    }
                    .frame(width: t, height: height, alignment: ch == "." ? .bottom : .center)
                } else if ch == "+" {
                    Text("+").font(.system(size: height * 0.7, weight: .black, design: .monospaced)).foregroundStyle(on).frame(width: w * 0.8)
                } else {
                    digit(SevenSeg.map[ch] ?? SevenSeg.map[" "]!, w: w, t: t)
                }
            }
        }
        .frame(height: height)
        .shadow(color: on.opacity(0.55), radius: height * 0.12)
    }

    func dot(_ t: CGFloat) -> some View { RoundedRectangle(cornerRadius: t * 0.3).fill(on).frame(width: t, height: t) }

    func digit(_ seg: [Bool], w: CGFloat, t: CGFloat) -> some View {
        Canvas { ctx, s in
            let W = s.width, H = s.height, g = t * 0.18, sk = W * 0.08
            func bar(_ x: CGFloat, _ y: CGFloat, _ len: CGFloat, horizontal: Bool) -> Path {
                var p = Path()
                if horizontal {
                    p.move(to: CGPoint(x: x + g, y: y)); p.addLine(to: CGPoint(x: x + t / 2 + g, y: y - t / 2))
                    p.addLine(to: CGPoint(x: x + len - t / 2 - g, y: y - t / 2)); p.addLine(to: CGPoint(x: x + len - g, y: y))
                    p.addLine(to: CGPoint(x: x + len - t / 2 - g, y: y + t / 2)); p.addLine(to: CGPoint(x: x + t / 2 + g, y: y + t / 2))
                } else {
                    p.move(to: CGPoint(x: x, y: y + g)); p.addLine(to: CGPoint(x: x + t / 2, y: y + t / 2 + g))
                    p.addLine(to: CGPoint(x: x + t / 2, y: y + len - t / 2 - g)); p.addLine(to: CGPoint(x: x, y: y + len - g))
                    p.addLine(to: CGPoint(x: x - t / 2, y: y + len - t / 2 - g)); p.addLine(to: CGPoint(x: x - t / 2, y: y + t / 2 + g))
                }
                p.closeSubpath()
                return p
            }
            let half = H / 2
            let bars: [Path] = [
                bar(t / 2, t / 2, W - t, horizontal: true),          // a
                bar(W - t / 2, t / 2, half - t / 2, horizontal: false), // b
                bar(W - t / 2, half, half - t / 2, horizontal: false),  // c
                bar(t / 2, H - t / 2, W - t, horizontal: true),       // d
                bar(t / 2, half, half - t / 2, horizontal: false),      // e
                bar(t / 2, t / 2, half - t / 2, horizontal: false),     // f
                bar(t / 2, half, W - t, horizontal: true),            // g
            ]
            // A slight forward lean, like real LED clocks.
            let lean = CGAffineTransform(a: 1, b: 0, c: -0.08, d: 1, tx: sk, ty: 0)
            for (i, b) in bars.enumerated() {
                ctx.fill(b.applying(lean), with: .color(seg[i] ? on : off))
            }
        }
        .frame(width: w, height: height)
    }
}

/// The finish clock: black housing, amber LEDs, a small caption.
struct FinishClock: View {
    let time: String
    var caption: String? = nil
    var height: CGFloat = 70
    var color: Color = Track.led
    var body: some View {
        VStack(spacing: 8) {
            SevenSeg(text: time, height: height, on: color)
            if let caption {
                Text(caption.uppercased()).font(.system(size: 11, weight: .heavy)).tracking(2).foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 20).padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Track.clock)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.02)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black).padding(8).opacity(0.6))
                .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
        )
    }
}

// MARK: - Formatting

enum Fmt {
    /// 3:29:45 or 23:04
    static func clock(_ s: TimeInterval, forceHours: Bool = false) -> String {
        let t = Int(abs(s).rounded())
        let h = t / 3600, m = (t % 3600) / 60, sec = t % 60
        return h > 0 || forceHours ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }
    /// 7:59
    static func pace(_ s: TimeInterval) -> String {
        let t = Int(s.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }
    static func delta(_ s: TimeInterval) -> String { (s >= 0 ? "+" : "-") + clock(s) }
    static func day(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "EEE d MMM yyyy"; return f.string(from: d) }
}
