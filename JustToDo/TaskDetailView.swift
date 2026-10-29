import SwiftUI

struct TaskDetailView: View {
    @State var id: UUID
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false

    private var index: Int? { store.sorted.firstIndex { $0.id == id } }

    var body: some View {
        Group {
            if let task = store.task(id) {
                content(task)
            } else {
                Text("タスクが見つかりません").foregroundStyle(Color.jtMute)
            }
        }
        .background(Color.white)
        .navigationTitle("タスク詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("編集する", systemImage: "pencil") { showEditor = true }
                    Button("削除する", systemImage: "trash", role: .destructive) {
                        store.delete(id)
                        dismiss()
                    }
                } label: {
                    Image(systemName: "ellipsis").accessibilityLabel("その他の操作")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            if let task = store.task(id) { TaskEditorView(editing: task) }
        }
    }

    private func move(_ delta: Int) {
        guard let i = index else { return }
        let j = min(max(i + delta, 0), store.sorted.count - 1)
        id = store.sorted[j].id
        store.selectedID = id
    }

    private func content(_ task: TaskItem) -> some View {
        let half = store.half(of: task)
        let state = store.state(task)
        return VStack(spacing: 0) {
            ClockView(
                arcs: store.arcs(half: half, selected: task.id, running: false),
                handsMinutes: Double(task.startMin),
                caption: "\(amPm(half)) ・ 開始",
                centerText: hm(task.startMin),
                spoken: "\(task.title)、\(amPm(half))\(task.rangeText())"
            )
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    CircleArrowButton(systemName: "chevron.left", label: "前のタスク",
                                      enabled: (index ?? 0) > 0) { move(-1) }
                    VStack(alignment: .leading, spacing: 6) {
                        StateLabel(state: state)
                        Text(task.title)
                            .font(.system(size: 24, weight: .bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text(task.rangeText())
                            .font(.system(size: 17)).foregroundStyle(Color.jtMute).monospacedDigit()
                        TagChip(tag: task.tag)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    CircleArrowButton(systemName: "chevron.right", label: "次のタスク",
                                      enabled: (index ?? 0) < store.sorted.count - 1) { move(1) }
                }

                if store.isWaitingToStart(task) {
                    if let late = store.lateText(task) {
                        Text("\(late)。遅れた分は赤で記録されます")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.jtRed)
                    } else {
                        Text("開始から1分以内にスタートすれば遅刻になりません")
                            .font(.system(size: 14)).foregroundStyle(Color.jtMute)
                    }
                } else if let late = store.lateText(task) {
                    Text("\(late)で記録済み").font(.system(size: 14)).foregroundStyle(Color.jtRed)
                }

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.jtMute)
                        .padding(.horizontal, 4)
                }

                HStack(spacing: 10) {
                    Button { showEditor = true } label: { Text("編集する") }
                        .buttonStyle(FilledButtonStyle(fill: .white, foreground: .jtInk, stroke: .jtLine))
                        .frame(width: 112)
                    NavigationLink(value: Route.focus(task.id)) {
                        HStack {
                            Image(systemName: "scope")
                            Text("集中をはじめる")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .padding(.horizontal, 18)
                    }
                    .buttonStyle(FilledButtonStyle())
                    .disabled(task.isDone)
                    .opacity(task.isDone ? 0.4 : 1)
                }
            }
            .padding(16)
            .jtCard()
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }
}
