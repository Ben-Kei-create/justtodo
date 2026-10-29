import SwiftUI

struct TaskListView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var showEditor = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.sorted) { task in
                    NavigationLink(value: Route.detail(task.id)) {
                        HStack(spacing: 12) {
                            Button {
                                store.setDone(task.id, !task.isDone)
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(task.isDone ? Color.jtBlue : Color.jtArc)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(task.isDone ? "完了を取り消す" : "完了にする")
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .strikethrough(task.isDone)
                                    .foregroundStyle(task.isDone ? Color.jtMute : Color.jtInk)
                                Text(task.rangeText()).font(.system(size: 14)).foregroundStyle(Color.jtMute)
                                    .monospacedDigit()
                            }
                            Spacer()
                            TagChip(tag: task.tag)
                        }
                    }
                }
                .onDelete { offsets in
                    let list = store.sorted
                    offsets.forEach { store.delete(list[$0].id) }
                }
            }
            .overlay {
                if store.tasks.isEmpty {
                    Text("タスクはまだありません").foregroundStyle(Color.jtMute)
                }
            }
            .navigationTitle("タスク")
            .toolbar {
                Button { showEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("タスクを追加")
            }
            .sheet(isPresented: $showEditor) { TaskEditorView() }
            .routeDestinations()
        }
    }
}

struct StatsView: View {
    @EnvironmentObject private var store: TaskStore

    private var planned: Int { store.tasks.reduce(0) { $0 + $1.duration } }
    private var focused: Int { store.tasks.reduce(0) { $0 + $1.focusedSeconds } / 60 }
    private var late: Int { Int(store.tasks.reduce(0) { $0 + store.lateMinutes($1) }.rounded()) }
    private var done: Int { store.tasks.filter(\.isDone).count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        tile("完了", "\(done)/\(store.tasks.count)")
                        tile("集中した時間", "\(focused)分")
                    }
                    HStack(spacing: 12) {
                        tile("予定の合計", "\(planned / 60)時間\(planned % 60)分")
                        tile("遅刻の合計", "\(late)分")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("分類ごとの予定時間").font(.system(size: 15, weight: .semibold))
                        ForEach(TaskTag.allCases) { tag in
                            let minutes = store.tasks.filter { $0.tag == tag }.reduce(0) { $0 + $1.duration }
                            HStack(spacing: 10) {
                                Text(tag.rawValue).font(.system(size: 14)).frame(width: 84, alignment: .leading)
                                GeometryReader { g in
                                    Capsule().fill(Color.jtTrack)
                                    Capsule().fill(Color.jtBlue)
                                        .frame(width: planned == 0 ? 0 : g.size.width * CGFloat(minutes) / CGFloat(planned))
                                }
                                .frame(height: 10)
                                Text("\(minutes)分").font(.system(size: 13)).foregroundStyle(Color.jtMute)
                                    .frame(width: 52, alignment: .trailing).monospacedDigit()
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .jtCard()
                }
                .padding(16)
            }
            .navigationTitle("統計")
        }
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13)).foregroundStyle(Color.jtMute)
            Text(value).font(.system(size: 26, weight: .bold)).monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .jtCard()
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: TaskStore
    @AppStorage("hasStarted") private var hasStarted = true
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("はじめの画面をもう一度見る") { hasStarted = false }
                    Button("サンプルのタスクに戻す") { store.resetSamples() }
                }
                Section {
                    Button("すべてのタスクを削除", role: .destructive) { confirmClear = true }
                }
                Section {
                    LabeledContent("バージョン", value: "1.0")
                }
            }
            .navigationTitle("設定")
            .confirmationDialog("すべてのタスクを削除しますか？", isPresented: $confirmClear,
                                titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    store.tasks = []
                    store.selectedID = nil
                }
            }
        }
    }
}
