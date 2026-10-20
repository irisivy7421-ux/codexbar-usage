import Foundation

enum CodexAppServerError: LocalizedError {
    case executableNotFound
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound: "找不到 Codex。请先安装或打开 Codex 桌面版。"
        case .invalidResponse: "Codex 返回的数据格式无法识别。"
        case .server(let message): message
        }
    }
}

actor CodexAppServerClient {
    private var process: Process?
    private var input: FileHandle?
    private var continuations: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private var nextID = 1
    private var initialized = false

    func readUsage() async throws -> UsageSnapshot {
        try startIfNeeded()
        if !initialized {
            _ = try await request(method: "initialize", params: [
                "clientInfo": ["name": "codexbar", "title": "CodexBar", "version": "0.1.0"],
                "capabilities": ["experimentalApi": false]
            ])
            initialized = true
        }
        let result = try await request(method: "account/rateLimits/read", params: [:])
        return try UsageSnapshot.decode(from: result)
    }

    private func startIfNeeded() throws {
        if process?.isRunning == true { return }
        guard let url = codexExecutableURL() else { throw CodexAppServerError.executableNotFound }

        let task = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        task.executableURL = url
        task.arguments = ["app-server", "--stdio"]
        task.standardInput = stdin
        task.standardOutput = stdout
        task.standardError = FileHandle.nullDevice
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.split(separator: "\n") { self?.receive(String(line)) }
        }
        task.terminationHandler = { [weak self] _ in
            Task { [weak self] in
                await self?.didTerminate()
            }
        }
        try task.run()
        process = task
        input = stdin.fileHandleForWriting
        initialized = false
    }

    private func codexExecutableURL() -> URL? {
        // Codex Desktop 0.163 moved the bundled executable into CodexCLI.app.
        // Keep the former path so installations that have not updated still work.
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/MacOS/codex",
            "/Applications/Codex.app/Contents/Resources/codex"
        ]

        guard let path = candidates.first(where: FileManager.default.isExecutableFile) else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    private func request(method: String, params: [String: Any]) async throws -> [String: Any] {
        guard let input else { throw CodexAppServerError.server("Codex 本地服务没有启动成功。") }
        let id = nextID
        nextID += 1
        let payload: [String: Any] = ["id": id, "method": method, "params": params]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try await withCheckedThrowingContinuation { continuation in
            continuations[id] = continuation
            input.write(data + Data([0x0A]))
        }
    }

    nonisolated private func receive(_ line: String) {
        guard let data = line.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        Task { await handle(object) }
    }

    private func handle(_ object: [String: Any]) {
        guard let id = object["id"] as? Int, let continuation = continuations.removeValue(forKey: id) else { return }
        if let error = object["error"] as? [String: Any] {
            continuation.resume(throwing: CodexAppServerError.server(error["message"] as? String ?? "Codex 服务请求失败。"))
        } else if let result = object["result"] as? [String: Any] {
            continuation.resume(returning: result)
        } else {
            continuation.resume(throwing: CodexAppServerError.invalidResponse)
        }
    }

    private func didTerminate() {
        process = nil
        input = nil
        initialized = false
        let waiting = continuations
        continuations.removeAll()
        waiting.values.forEach { $0.resume(throwing: CodexAppServerError.server("Codex 本地服务已停止。")) }
    }
}

private extension UsageSnapshot {
    static func decode(from result: [String: Any]) throws -> UsageSnapshot {
        let primary = result["rateLimits"] as? [String: Any]
        let extra = (result["rateLimitsByLimitId"] as? [String: [String: Any]])?.map(\.value) ?? []
        let buckets = [primary].compactMap { $0 } + extra
        let windows = buckets.flatMap { bucket -> [UsageWindow] in
            [bucket["primary"], bucket["secondary"]].compactMap { value in
                guard let window = value as? [String: Any], let used = window["usedPercent"] as? Int else { return nil }
                let reset = (window["resetsAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
                    ?? (window["resetsAt"] as? Int).map { Date(timeIntervalSince1970: TimeInterval($0)) }
                return UsageWindow(durationMinutes: window["windowDurationMins"] as? Int, usedPercent: used, resetsAt: reset)
            }
        }
        guard !windows.isEmpty else { throw CodexAppServerError.invalidResponse }
        let credits = result["rateLimitResetCredits"] as? [String: Any]
        let details = (credits?["credits"] as? [[String: Any]] ?? []).compactMap { item -> ResetCredit? in
            guard let id = item["id"] as? String else { return nil }
            let expiry = (item["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
                ?? (item["expiresAt"] as? Int).map { Date(timeIntervalSince1970: TimeInterval($0)) }
            return ResetCredit(id: id, expiresAt: expiry)
        }
        return UsageSnapshot(windows: windows, resetCreditsAvailable: credits?["availableCount"] as? Int ?? 0, resetCredits: details)
    }
}
