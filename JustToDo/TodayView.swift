import SwiftUI

extension View {
    func routeDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .detail(let id): TaskDetailView(id: id)
            case .focus(let id): FocusView(id: id)
            }
        }
    }
}

func amPm(_ half: Int) -> String { half == 0 ? "午前" : "午後" }

struct TodayView: View {
    @EnvironmentObject private var store: TaskStore
    @State private var showEditor = false

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: store.now)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日").font(.system(size: 38, weight: .heavy))
                    Text(dateText).font(.system(size: 15)).foregroundStyle(Color.jtMute)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                let selected = store.selected
                let half = selected.map { store.half(of: $0) } ?? store.nowHalf
                ClockView(
                    arcs: store.arcs(half: half, selected: selected?.id),
                    handsMinutes: store.nowMinutes,
                    caption: amPm(half),
                    centerText: store.nowText,
                    spoken: "現在 \(amPm(store.nowHalf)) \(store.nowText)。表示中は\(amPm(half))の予定"
                )
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 8)

                if let selected {
                    TodayCard(task: selected)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                } else {
                    emptyState
                }
            }
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEditor) { TaskEditorView() }
            .routeDestinations()
        }
    }

    private var header: some View {
        HStack {
            Text("JUST DO TIME")
                .font(.system(size: 19, weight: .black))
                .tracking(-0.5)
            Spacer()
            Button { store.selectedID = nil } label: {
                Image(systemName: "calendar").font(.system(size: 20))
            }
            .accessibilityLabel("今の予定に戻る")
            Button { showEditor = true } label: {
                Image(systemName: "plus").font(.system(size: 22, weight: .regular))
            }
            .accessibilityLabel("タスクを追加")
            .padding(.leading, 14)
        }
        .foregroundStyle(Color.jtInk)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("今日のやることを登録しよう").font(.system(size: 17, weight: .semibold))
            Button { showEditor = true } label: { Text("タスクを追加") }
                .buttonStyle(FilledButtonStyle(fill: .jtBlue))
        }
        .padding(16)
        .jtCard()
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

struct TodayCard: View {
    let task: TaskItem
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        let state = store.state(task)
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                CircleArrowButton(systemName: "chevron.left", label: "前のタスク", enabled: store.hasPrev) {
                    store.step(-1)
                }
                NavigationLink(value: Route.detail(task.id)) {
                    VStack(alignment: .leading, spacing: 4) {
                        StateLabel(state: state)
                        Text(task.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.jtInk)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        HStack(spacing: 8) {
                            Text(task.rangeText()).foregroundStyle(Color.jtMute)
                            if state == .running {
                                Text("残り\(store.remainingMinutes(task))分")
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.jtBlue)
                            }
                            if let late = store.lateText(task) {
                                Text(late).fontWeight(.bold).foregroundStyle(Color.jtRed)
                            }
                        }
                        .font(.system(size: 16))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                CircleArrowButton(systemName: "chevron.right", label: "次のタスク", enabled: store.hasNext) {
                    store.step(1)
                }
            }

            Button {
                store.setDone(task.id, !task.isDone)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: task.isDone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                    Text(task.isDone ? "完了を取り消す" : "このタスクを完了する")
                }
            }
            .buttonStyle(FilledButtonStyle(fill: task.isDone ? .jtTrack : .jtBlue,
                                           foreground: task.isDone ? .jtInk : .white))

            if let next = store.next(after: task) {
                Divider()
                NavigationLink(value: Route.detail(next.id)) {
                    HStack(spacing: 10) {
                        Circle().fill(Color.jtMute).frame(width: 8, height: 8)
                        Text("NEXT").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.jtMute)
                        Text(hm(next.startMin)).font(.system(size: 14)).foregroundStyle(Color.jtMute).monospacedDigit()
                        Text(next.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.jtInk)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.jtMute)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .jtCard()
    }
}
