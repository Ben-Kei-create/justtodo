import SwiftUI

extension Color {
    static let jtBlue = Color(red: 0.03, green: 0.38, blue: 1.0)
    static let jtInk = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let jtMute = Color(red: 0.55, green: 0.55, blue: 0.58)
    static let jtTrack = Color(red: 0.945, green: 0.945, blue: 0.955)
    static let jtArc = Color(red: 0.82, green: 0.82, blue: 0.84)
    static let jtLine = Color(red: 0.90, green: 0.90, blue: 0.92)
    static let jtRed = Color(red: 0.93, green: 0.22, blue: 0.20)
    static let jtChip = Color(red: 0.89, green: 0.93, blue: 1.0)
}

extension View {
    func jtCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 18, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.jtLine.opacity(0.6), lineWidth: 1)
        )
    }
}

struct FilledButtonStyle: ButtonStyle {
    var fill: Color = .jtInk
    var foreground: Color = .white
    var stroke: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(stroke, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct CircleArrowButton: View {
    let systemName: String
    let label: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.jtInk)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white))
                .overlay(Circle().stroke(Color.jtLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}

struct TagChip: View {
    let tag: TaskTag

    var body: some View {
        Text(tag.rawValue)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tag == .work ? Color.jtBlue : Color.jtMute)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(tag == .work ? Color.jtChip : Color.jtTrack))
    }
}

struct StateLabel: View {
    let state: TaskState
    var pausedText: String? = nil

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(state.color).frame(width: 8, height: 8)
            Text(pausedText ?? state.text)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(state.color)
        }
        .accessibilityElement(children: .combine)
    }
}
