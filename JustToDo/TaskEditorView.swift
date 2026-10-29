import SwiftUI

struct TaskEditorView: View {
    var editing: TaskItem? = nil
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var shortTitle = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var tag: TaskTag = .work
    @State private var note = ""

    private func date(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private func minutes(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && minutes(end) > minutes(start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("やること") {
                    TextField("例：企画書を仕上げる", text: $title)
                    TextField("時計に表示する短い名前（任意）", text: $shortTitle)
                }
                Section("時間") {
                    DatePicker("開始", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("終了", selection: $end, displayedComponents: .hourAndMinute)
                    if minutes(end) <= minutes(start) {
                        Text("終了は開始より後にしてください").font(.footnote).foregroundStyle(.red)
                    }
                }
                Section("分類") {
                    Picker("分類", selection: $tag) {
                        ForEach(TaskTag.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("メモ") {
                    TextField("メモ", text: $note, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle(editing == nil ? "タスクを追加" : "タスクを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(!valid)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let t = editing {
            title = t.title; shortTitle = t.shortTitle; tag = t.tag; note = t.note
            start = date(t.startMin); end = date(t.endMin)
        } else {
            let s = store.suggestedStart()
            start = date(s); end = date(min(s + 30, 1439))
        }
    }

    private func save() {
        var task = editing ?? TaskItem(title: "", startMin: 0, endMin: 0)
        task.title = title.trimmingCharacters(in: .whitespaces)
        task.shortTitle = shortTitle.trimmingCharacters(in: .whitespaces)
        task.startMin = minutes(start)
        task.endMin = minutes(end)
        task.tag = tag
        task.note = note
        store.upsert(task)
        dismiss()
    }
}
