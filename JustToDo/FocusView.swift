import SwiftUI
import Combine
import UIKit

struct FocusView: View {
    let id: UUID
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss

    @State private var total: TimeInterval = 1
    @State private var remaining: TimeInterval = 0
    @State private var running = true
    @State private var lastTick = Date()
    @State private var committed: TimeInterval = 0
    @State private var showTimeUp = false
    @State private var ready = false
    @State private var customMinutes = 15

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let task = store.task(id) {
                content(task)
            } else {
                Text("タスクが見つかりません").foregroundStyle(Color.jtMute)
            }
        }
        .background(Color.white)
        .navigationTitle("集中モード")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: setup)
        .onDisappear {
            commit()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(timer) { _ in tick() }
        .sheet(isPresented: $showTimeUp) { timeUpSheet }
    }

    // MARK: Timer

    private func setup() {
        guard !ready, let task = store.task(id) else { return }
        ready = true
        if !task.isDone { store.markStarted(id) }
        let full = TimeInterval(task.duration * 60)
        let left = (Double(task.endMin) - store.nowMinutes) * 60
        total = max(full, 1)
        remaining = store.state(task) == .running ? max(left, 1) : full
        lastTick = Date()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func tick() {
        let dt = Date().timeIntervalSince(lastTick)
        lastTick = Date()
        guard ready, running, !showTimeUp else { return }
        remaining -= dt
        if remaining <= 0 {
            remaining = 0
            running = false
            commit()
            showTimeUp = true
        }
    }

    private func commit() {
        let elapsed = max(0, total - remaining)
        store.addFocus(id, seconds: Int(elapsed - committed))
        committed = elapsed
    }

    private func togglePause() {
        lastTick = Date()
        running.toggle()
        if !running { commit() }
    }

    private var remainingText: String {
        let s = Int(remaining.rounded(.up))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
            : String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: UI

    private func content(_ task: TaskItem) -> some View {
        let half = store.half(of: task)
        return VStack(spacing: 0) {
            ClockView(
                arcs: store.arcs(half: half, selected: task.id, running: false),
                handsMinutes: store.nowMinutes,
                caption: "残り",
                centerText: remainingText,
                centerFont: .system(size: 26, weight: .bold),
                remaining: remaining / total,
                spoken: "残り\(remainingText)"
            )
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    StateLabel(state: .running, pausedText: running ? "進行中" : "一時停止中")
                        .opacity(running ? 1 : 0.7)
                    Text(task.title.hasSuffix("集中する") ? task.title : "\(task.title)に集中する")
                        .font(.system(size: 24, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(task.rangeText())
                        .font(.system(size: 17)).foregroundStyle(Color.jtMute).monospacedDigit()
                    TagChip(tag: task.tag)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button(action: togglePause) {
                        HStack(spacing: 8) {
                            Image(systemName: running ? "pause.fill" : "play.fill")
                            Text(running ? "一時停止" : "再開")
                        }
                    }
                    .buttonStyle(FilledButtonStyle(fill: .white, foreground: .jtInk, stroke: .jtLine))
                    Button {
                        commit()
                        store.setDone(id, true)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                            Text("完了する")
                        }
                    }
                    .buttonStyle(FilledButtonStyle(fill: .jtBlue))
                }
            }
            .padding(16)
            .jtCard()
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }

    /// Most minutes the task can still be pushed back today (it can't run past midnight).
    private var maxExtend: Int { min(180, 1440 - (store.task(id)?.endMin ?? 1440)) }

    private func extend(by minutes: Int) {
        let add = min(minutes, maxExtend)
        guard add > 0 else { return }
        store.extend(id, minutes: add)
        total += TimeInterval(add * 60)
        remaining += TimeInterval(add * 60)
        lastTick = Date()
        running = true
        showTimeUp = false
    }

    /// Time ran out: never auto-complete — let the person decide.
    private var timeUpSheet: some View {
        VStack(spacing: 14) {
            Text("予定の時間になりました").font(.system(size: 20, weight: .bold))
            Text("「\(store.task(id)?.title ?? "")」をどうしますか？")
                .font(.system(size: 15)).foregroundStyle(Color.jtMute)
                .multilineTextAlignment(.center)
            Button { extend(by: 5) } label: { Text("5分延長する") }
                .buttonStyle(FilledButtonStyle(fill: .jtBlue))
                .disabled(maxExtend < 1)

            // Custom extension: spin the wheel, then confirm.
            HStack(spacing: 6) {
                Picker("延長する分", selection: $customMinutes) {
                    ForEach(1...max(1, maxExtend), id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 92, height: 96)
                .clipped()
                Text("分").font(.system(size: 17, weight: .semibold))
                Spacer(minLength: 4)
                Button { extend(by: customMinutes) } label: { Text("延長する") }
                    .buttonStyle(FilledButtonStyle(fill: .white, foreground: .jtBlue, stroke: .jtBlue))
                    .frame(width: 128)
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.jtTrack))
            .disabled(maxExtend < 1)
            .accessibilityElement(children: .contain)
            HStack(spacing: 10) {
                Button {
                    showTimeUp = false
                    dismiss()
                } label: { Text("あとで") }
                    .buttonStyle(FilledButtonStyle(fill: .white, foreground: .jtInk, stroke: .jtLine))
                Button {
                    store.setDone(id, true)
                    showTimeUp = false
                    dismiss()
                } label: { Text("完了にする") }
                    .buttonStyle(FilledButtonStyle())
            }
        }
        .padding(24)
        .presentationDetents([.height(460)])
        .interactiveDismissDisabled()
    }
}
