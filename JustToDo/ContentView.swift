import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var store = TaskStore()
    @AppStorage("hasStarted") private var hasStarted = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if hasStarted {
                MainTabs()
            } else {
                WelcomeView { hasStarted = true }
            }
        }
        .environmentObject(store)
        .preferredColorScheme(.light)
        .tint(.jtBlue)
        .onReceive(timer) { _ in store.tick() }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            Tab("今日", systemImage: "house.fill") { TodayView() }
            Tab("タスク", systemImage: "checklist") { TaskListView() }
            Tab("統計", systemImage: "chart.bar.fill") { StatsView() }
            Tab("設定", systemImage: "gearshape") { SettingsView() }
        }
    }
}

#Preview {
    ContentView()
}
