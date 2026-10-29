import SwiftUI

struct ClockArc: Identifiable, Equatable {
    enum Style { case normal, selected, running }

    let id: UUID
    let start: Int   // minutes within the displayed 12h half, 0...720
    let end: Int
    let label: String
    let range: String
    let style: Style
    /// nil = the whole start...end span. Ranges are minutes within the displayed half.
    var solid: ClosedRange<Double>? = nil
    var noSolid = false
    var late: ClosedRange<Double>? = nil
    var pending: ClosedRange<Double>? = nil
}

enum ClockLabels { case none, full, compact }

private struct Metrics {
    let c: CGPoint
    let R: CGFloat
    let ringW: CGFloat
    let ringR: CGFloat
    let ri: CGFloat

    func point(_ r: CGFloat, _ deg: Double) -> CGPoint {
        let a = deg * .pi / 180
        return CGPoint(x: c.x + r * CGFloat(sin(a)), y: c.y - r * CGFloat(cos(a)))
    }
}

/// 12-hour clock whose outer ring shows the day's tasks as arcs.
struct ClockView: View {
    var arcs: [ClockArc]
    var handsMinutes: Double
    var caption: String? = nil
    var centerText: String = ""
    var centerFont: Font = .system(size: 16, weight: .semibold)
    var labels: ClockLabels = .full
    /// Remaining fraction (0...1) of a running task, drawn as an inner arc.
    var remaining: Double? = nil
    var spoken: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var hasPending: Bool { arcs.contains { $0.pending != nil } }

    private func deg(_ minutes: Int) -> Double { Double(minutes) / 720 * 360 }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let margin: CGFloat = labels == .none ? 2 : 30
            // Side labels need room beside the ring, so cap the radius by label width too.
            let labelW: CGFloat = labels == .full ? 66 : 52
            let byWidth = labels == .none ? CGFloat.infinity : (W / 2 - labelW * 0.78) / 0.92 - 12
            let R = max(20, min(W / 2 - margin, H / 2 - margin, byWidth))
            let ringW = R * 0.13
            let m = Metrics(c: CGPoint(x: W / 2, y: H / 2), R: R, ringW: ringW,
                            ringR: R - ringW / 2, ri: R - ringW - 4)

            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !hasPending || reduceMotion)) { tl in
                    // Slow ~2.6s breathing for the part still waiting to be started.
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let pulse = (hasPending && !reduceMotion) ? 0.62 + 0.38 * sin(t * 2 * .pi / 2.6) : 1.0
                    Canvas { ctx, _ in drawFace(&ctx, m, pulse: pulse) }
                }

                ForEach(1...12, id: \.self) { n in
                    Text("\(n)")
                        .font(.system(size: max(11, m.R * 0.095), weight: .medium))
                        .foregroundStyle(Color.jtInk)
                        .position(m.point(m.ri * 0.74, Double(n) * 30))
                }

                Canvas { ctx, _ in drawHands(&ctx, m) }

                if labels != .none {
                    ForEach(arcs) { arc in label(for: arc, m: m, size: CGSize(width: W, height: H)) }
                }

                VStack(spacing: 1) {
                    if let caption {
                        Text(caption)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.jtMute)
                    }
                    if !centerText.isEmpty {
                        Text(centerText)
                            .font(centerFont)
                            .monospacedDigit()
                            .foregroundStyle(Color.jtInk)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
                .position(x: m.c.x, y: m.c.y + m.ri * 0.40)
            }
            .frame(width: W, height: H)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken.isEmpty ? "時計" : spoken)
    }

    // MARK: Drawing

    private func drawFace(_ ctx: inout GraphicsContext, _ m: Metrics, pulse: Double) {
        let track = Path(ellipseIn: CGRect(x: m.c.x - m.ringR, y: m.c.y - m.ringR,
                                           width: m.ringR * 2, height: m.ringR * 2))
        ctx.stroke(track, with: .color(.jtTrack), lineWidth: m.ringW)

        func strokeArc(_ ctx: inout GraphicsContext, _ r: ClosedRange<Double>, _ color: Color,
                       width: CGFloat? = nil, cap: CGLineCap = .butt, dash: [CGFloat] = []) {
            var p = Path()
            p.addArc(center: m.c, radius: m.ringR,
                     startAngle: .degrees(r.lowerBound / 720 * 360 - 90),
                     endAngle: .degrees(r.upperBound / 720 * 360 - 90), clockwise: false)
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: width ?? m.ringW, lineCap: cap, dash: dash))
        }

        for arc in arcs {
            let color: Color
            switch arc.style {
            case .selected: color = .jtBlue
            case .running: color = Color.jtBlue.opacity(0.4)
            case .normal: color = .jtArc
            }
            if !arc.noSolid { strokeArc(&ctx, arc.solid ?? Double(arc.start)...Double(arc.end), color) }
            if let late = arc.late { strokeArc(&ctx, late, .jtRed) }
            if let pending = arc.pending {
                // Faint band plus a dotted centre line that breathes.
                strokeArc(&ctx, pending, color.opacity(0.14 * pulse))
                strokeArc(&ctx, pending, color.opacity(pulse), width: m.ringW * 0.34, cap: .round, dash: [0.1, 7])
            }
        }

        for i in 0..<60 {
            let major = i % 5 == 0
            let a = Double(i) * 6
            var p = Path()
            p.move(to: m.point(m.ri, a))
            p.addLine(to: m.point(m.ri - (major ? 7 : 3.5), a))
            ctx.stroke(p, with: .color(Color.jtMute.opacity(major ? 0.9 : 0.55)),
                       lineWidth: major ? 1.5 : 1)
        }

        if let remaining {
            let frac = min(max(remaining, 0), 1)
            var p = Path()
            p.addArc(center: m.c, radius: m.ri - 13,
                     startAngle: .degrees(-90 + (1 - frac) * 360), endAngle: .degrees(270),
                     clockwise: false)
            ctx.stroke(p, with: .color(Color.jtBlue.opacity(0.35)),
                       style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
    }

    private func drawHands(_ ctx: inout GraphicsContext, _ m: Metrics) {
        let half = handsMinutes.truncatingRemainder(dividingBy: 720)
        let hourAngle = half / 720 * 360
        let minuteAngle = handsMinutes.truncatingRemainder(dividingBy: 60) / 60 * 360

        func hand(_ angle: Double, length: CGFloat, width: CGFloat) {
            var p = Path()
            p.move(to: m.point(-length * 0.14, angle))
            p.addLine(to: m.point(length, angle))
            ctx.stroke(p, with: .color(.jtInk), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        hand(hourAngle, length: m.ri * 0.52, width: 4.5)
        hand(minuteAngle, length: m.ri * 0.82, width: 3.5)

        ctx.fill(Path(ellipseIn: CGRect(x: m.c.x - 5, y: m.c.y - 5, width: 10, height: 10)),
                 with: .color(.jtInk))

        guard labels == .full else { return }
        for arc in arcs {
            let a = deg(arc.start)
            var p = Path()
            p.move(to: m.point(m.R + 1, a))
            p.addLine(to: m.point(m.R + 13, a))
            let selected = arc.style == .selected
            ctx.stroke(p, with: .color(selected ? .jtBlue : Color.jtArc), lineWidth: 1)
            if selected {
                let q = m.point(m.R - m.ringW * 0.25, a)
                let dot = CGRect(x: q.x - 4, y: q.y - 4, width: 8, height: 8)
                ctx.fill(Path(ellipseIn: dot), with: .color(.jtBlue))
                ctx.stroke(Path(ellipseIn: dot), with: .color(.white), lineWidth: 1.5)
            }
        }
    }

    private func label(for arc: ClockArc, m: Metrics, size: CGSize) -> some View {
        let full = labels == .full
        let wL: CGFloat = full ? 66 : 52
        let hL: CGFloat = full ? 30 : 26
        let a = deg(arc.start)
        let s = CGFloat(sin(a * .pi / 180)), cs = CGFloat(cos(a * .pi / 180))
        let q = m.point(m.R + (full ? 18 : 9), a)
        let side: Int = s > 0.35 ? 1 : (s < -0.35 ? -1 : 0)
        let cx = min(max(q.x + CGFloat(side) * wL / 2, wL / 2 + 4), size.width - wL / 2 - 4)
        let cy = min(max(q.y - cs * hL / 2, hL / 2 + 2), size.height - hL / 2 - 2)
        let selected = arc.style == .selected
        let alignment: HorizontalAlignment = side > 0 ? .leading : (side < 0 ? .trailing : .center)
        let frameAlign: Alignment = side > 0 ? .leading : (side < 0 ? .trailing : .center)

        return VStack(alignment: alignment, spacing: 0) {
            Text(arc.label)
                .font(.system(size: full ? 11.5 : 9.5, weight: .semibold))
                .foregroundStyle(selected ? Color.jtBlue : Color.jtInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(full ? arc.range : String(arc.range.prefix { $0 != "–" }))
                .font(.system(size: full ? 10 : 8.5))
                .monospacedDigit()
                .foregroundStyle(selected ? Color.jtBlue : Color.jtMute)
                .lineLimit(1)
        }
        .frame(width: wL, height: hL, alignment: frameAlign)
        .position(x: cx, y: cy)
    }
}
