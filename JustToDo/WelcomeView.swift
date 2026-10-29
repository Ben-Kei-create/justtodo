import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    private let arcs: [ClockArc] = [
        ClockArc(id: UUID(), start: 600, end: 660, label: "企画書", range: "10:00–11:00", style: .selected),
        ClockArc(id: UUID(), start: 660, end: 690, label: "打ち合わせ", range: "11:00–11:30", style: .normal),
        ClockArc(id: UUID(), start: 120, end: 150, label: "読書", range: "14:00–14:30", style: .selected),
        ClockArc(id: UUID(), start: 360, end: 420, label: "運動", range: "18:00–19:00", style: .selected),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: -12) {
                Text("JUST DO")
                Text("TIME")
            }
            .font(.system(size: 61, weight: .black))
            .tracking(-3.2)
            .foregroundStyle(Color.jtInk)
            .padding(.top, 24)
            .accessibilityElement(children: .combine)

            Text("時間と、やることを\nひとつに。")
                .font(.system(size: 28, weight: .bold))
                .lineSpacing(6)
                .foregroundStyle(Color.jtInk)
                .padding(.top, 20)

            Text("やることが、時間の中にある。\nだから、迷わず進める。")
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(Color.jtMute)
                .padding(.top, 14)

            ClockView(arcs: arcs, handsMinutes: 610, labels: .compact,
                      spoken: "予定が並んだ時計のイメージ")
                .frame(maxHeight: .infinity)
                .padding(.vertical, 8)

            Button(action: onStart) {
                HStack {
                    Spacer()
                    Text("はじめる")
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Image(systemName: "arrow.right").padding(.trailing, 20)
                }
            }
            .buttonStyle(FilledButtonStyle())
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 28)
        .background(Color.white)
    }
}
