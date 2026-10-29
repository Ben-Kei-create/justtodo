import SwiftUI
import Combine

enum TaskTag: String, Codable, CaseIterable, Identifiable {
    case work = "仕事"
    case personal = "自分の時間"
    case health = "運動"
    case other = "その他"

    var id: String { rawValue }
}

func hm(_ minutes: Int) -> String {
    String(format: "%d:%02d", minutes / 60, minutes % 60)
}

struct TaskItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var shortTitle: String = ""
    var startMin: Int
    var endMin: Int
    var tag: TaskTag = .work
    var note: String = ""
    var isDone = false
    var focusedSeconds = 0
    /// Minute-of-day when the person actually pressed start. nil = not started yet.
    var startedAt: Double? = nil

    var label: String { shortTitle.isEmpty ? String(title.prefix(6)) : shortTitle }
    var duration: Int { endMin - startMin }

    func rangeText(spaced: Bool = true) -> String {
        spaced ? "\(hm(startMin)) – \(hm(endMin))" : "\(hm(startMin))–\(hm(endMin))"
    }

    static let samples: [TaskItem] = [
        TaskItem(title: "企画書を仕上げる", shortTitle: "企画書", startMin: 600, endMin: 660, tag: .work),
        TaskItem(title: "チームの打ち合わせ", shortTitle: "打ち合わせ", startMin: 660, endMin: 690, tag: .work,
                 note: "進捗と次のアクションを確認"),
        TaskItem(title: "読書に集中する", shortTitle: "読書", startMin: 840, endMin: 870, tag: .personal),
        TaskItem(title: "運動", shortTitle: "運動", startMin: 1080, endMin: 1140, tag: .health),
    ]
}

enum TaskState {
    case done, running, upcoming, past

    var text: String {
        switch self {
        case .done: return "完了"
        case .running: return "NOW ・ 実行中"
        case .upcoming: return "NEXT ・ 予定"
        case .past: return "時間超過 ・ 未完了"
        }
    }

    var color: Color {
        switch self {
        case .running: return .jtBlue
        case .past: return .orange
        default: return .jtMute
        }
    }
}

enum Route: Hashable {
    case detail(UUID)
    case focus(UUID)
}

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] {
        didSet { save() }
    }
    @Published var now = Date()
    @Published var selectedID: UUID?

    private let key = "tasks.v1"
    private var offset: TimeInterval = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        } else {
            tasks = TaskItem.samples
        }
        // `-demoTime 10:10` pins the clock for screenshots and demos.
        if let demo = UserDefaults.standard.string(forKey: "demoTime") {
            let parts = demo.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2,
               let target = Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) {
                offset = target.timeIntervalSinceNow
            }
        }
        tick()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func tick() { now = Date().addingTimeInterval(offset) }

    // MARK: Time

    var nowMinutes: Double {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        return Double(c.hour ?? 0) * 60 + Double(c.minute ?? 0) + Double(c.second ?? 0) / 60
    }
    var nowHalf: Int { nowMinutes >= 720 ? 1 : 0 }
    var nowText: String { hm(Int(nowMinutes)) }

    func half(of task: TaskItem) -> Int { task.startMin >= 720 ? 1 : 0 }

    func state(_ task: TaskItem) -> TaskState {
        if task.isDone { return .done }
        let n = nowMinutes
        if n >= Double(task.startMin) && n < Double(task.endMin) { return .running }
        return n < Double(task.startMin) ? .upcoming : .past
    }

    /// Pressing start within this many minutes of the scheduled start still counts as on time.
    static let graceMinutes = 1.0

    /// The task's time has begun but start hasn't been pressed.
    func isWaitingToStart(_ task: TaskItem) -> Bool {
        !task.isDone && task.startedAt == nil
            && nowMinutes >= Double(task.startMin) && nowMinutes < Double(task.endMin)
    }

    /// Minutes between the scheduled start and the actual start (live while still waiting).
    func lateMinutes(_ task: TaskItem) -> Double {
        let late: Double
        if let started = task.startedAt {
            late = started - Double(task.startMin)
        } else if task.isDone {
            return 0
        } else {
            late = min(nowMinutes, Double(task.endMin)) - Double(task.startMin)
        }
        return late > Self.graceMinutes ? late : 0
    }

    func lateText(_ task: TaskItem) -> String? {
        let late = lateMinutes(task)
        return late > 0 ? "遅刻 \(max(1, Int(late.rounded())))分" : nil
    }

    func markStarted(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }), tasks[i].startedAt == nil else { return }
        tasks[i].startedAt = nowMinutes
    }

    func remainingMinutes(_ task: TaskItem) -> Int {
        max(0, Int((Double(task.endMin) - nowMinutes).rounded(.up)))
    }

    // MARK: Selection

    var sorted: [TaskItem] { tasks.sorted { $0.startMin < $1.startMin } }

    func task(_ id: UUID?) -> TaskItem? {
        guard let id else { return nil }
        return tasks.first { $0.id == id }
    }

    private var autoSelected: TaskItem? {
        let list = sorted
        return list.first { state($0) == .running }
            ?? list.first { !$0.isDone && Double($0.startMin) > nowMinutes }
            ?? list.first { !$0.isDone }
            ?? list.last
    }

    var selected: TaskItem? { task(selectedID) ?? autoSelected }

    private var selectedIndex: Int? {
        guard let id = selected?.id else { return nil }
        return sorted.firstIndex { $0.id == id }
    }

    var hasPrev: Bool { (selectedIndex ?? 0) > 0 }
    var hasNext: Bool { (selectedIndex ?? sorted.count) < sorted.count - 1 }

    func step(_ delta: Int) {
        guard let i = selectedIndex else { return }
        let j = min(max(i + delta, 0), sorted.count - 1)
        selectedID = sorted[j].id
    }

    func next(after task: TaskItem) -> TaskItem? {
        sorted.first { $0.startMin >= task.endMin && $0.id != task.id && !$0.isDone }
    }

    // MARK: Clock arcs

    func arcs(half: Int, selected: UUID?, running: Bool = true) -> [ClockArc] {
        let lo = half * 720, hi = lo + 720
        return sorted.compactMap { t in
            guard t.endMin > lo, t.startMin < hi else { return nil }
            let style: ClockArc.Style
            if t.id == selected { style = .selected }
            else if running && state(t) == .running { style = .running }
            else { style = .normal }
            var arc = ClockArc(id: t.id, start: max(t.startMin, lo) - lo, end: min(t.endMin, hi) - lo,
                               label: t.label, range: t.rangeText(spaced: false), style: style)

            // Late part is red; the part still waiting for start is dashed and pulses.
            let s = Double(t.startMin), e = Double(t.endMin)
            var solid: ClosedRange<Double>? = s...e
            var late: ClosedRange<Double>?
            var pending: ClosedRange<Double>?
            if let started = t.startedAt {
                if lateMinutes(t) > 0 {
                    late = s...min(started, e)
                    solid = started < e ? started...e : nil
                }
            } else if !t.isDone && nowMinutes >= s {
                let n = min(nowMinutes, e)
                if lateMinutes(t) > 0 { late = s...n }
                if n < e { pending = n...e }
                solid = (late == nil && n > s) ? s...n : nil
            }
            func clip(_ r: ClosedRange<Double>?) -> ClosedRange<Double>? {
                guard let r else { return nil }
                let a = max(r.lowerBound, Double(lo)), b = min(r.upperBound, Double(hi))
                return a < b ? (a - Double(lo))...(b - Double(lo)) : nil
            }
            arc.solid = clip(solid)
            arc.noSolid = arc.solid == nil
            arc.late = clip(late)
            arc.pending = clip(pending)
            return arc
        }
    }

    // MARK: Mutations

    func upsert(_ task: TaskItem) {
        if let i = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[i] = task
        } else {
            tasks.append(task)
        }
        selectedID = task.id
    }

    func delete(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil }
    }

    func setDone(_ id: UUID, _ done: Bool) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].isDone = done
        if done {
            // Finishing without ever pressing start still records when it was done.
            if tasks[i].startedAt == nil {
                tasks[i].startedAt = min(max(nowMinutes, Double(tasks[i].startMin)), Double(tasks[i].endMin))
            }
            selectedID = nil
        }
    }

    func extend(_ id: UUID, minutes: Int) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].endMin = min(1440, tasks[i].endMin + minutes)
    }

    func addFocus(_ id: UUID, seconds: Int) {
        guard seconds > 0, let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].focusedSeconds += seconds
    }

    func suggestedStart() -> Int {
        min(1380, (Int(nowMinutes) / 30 + 1) * 30)
    }

    func resetSamples() {
        tasks = TaskItem.samples
        selectedID = nil
    }
}
