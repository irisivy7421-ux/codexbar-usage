import SwiftUI
import AppKit

struct UsageMenu: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Codex Usage").font(.headline)
            if let snapshot = store.snapshot {
                if let fiveHour = snapshot.fiveHour { UsageRow(title: "5 小时额度", window: fiveHour, store: store) }
                if let weekly = snapshot.weekly { UsageRow(title: "每周额度", window: weekly, store: store) }
                Divider()
                Text("重置额度  \(snapshot.resetCreditsAvailable) 次可用").font(.headline)
                if snapshot.resetCredits.isEmpty {
                    Text(snapshot.resetCreditsAvailable == 0 ? "当前没有可用重置额度" : "Codex 未提供各额度的到期详情")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.resetCredits) { credit in
                        Text("到期：\(credit.expiresAt.map(store.resetText) ?? "无到期时间")")
                    }
                }
            } else {
                Text(store.errorMessage ?? "正在读取 Codex 的本地额度…").foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Text(store.updatedAt.map { "更新于 \($0.formatted(date: .omitted, time: .shortened))" } ?? "尚未更新")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("立即刷新") { store.refresh() }
                Button("退出") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 330)
    }
}

private struct UsageRow: View {
    let title: String
    let window: UsageWindow
    let store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title).font(.headline); Spacer(); Text("剩余 \(window.remainingPercent)%") }
            ProgressView(value: Double(window.remainingPercent), total: 100)
            Text("重置：\(store.resetText(window.resetsAt))").font(.caption).foregroundStyle(.secondary)
        }
    }
}
