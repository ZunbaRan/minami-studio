import Foundation
import AppKit

// Unix-socket NDJSON daemon. One request frame per line:
//   → {"id":"<rid>","cmd":"...","args":{...}}
//   ← {"id":"<rid>","ok":true,"data":{...}} | {"id":...,ok:false,error:{code,message,hint?}}
//   ← {"evt":true,"topic":"...","payload":{...}}   (pushed to subscribed connections)
// Concurrent in-flight requests per connection; responses correlate by id.

final class ConnectionContext {
    let fd: Int32
    private let writeLock = NSLock()
    var subscriptions = Set<String>()
    var readBuffer = Data()

    init(fd: Int32) { self.fd = fd }

    func send(_ line: String) {
        writeLock.lock()
        defer { writeLock.unlock() }
        let bytes = (line + "\n").data(using: .utf8)!
        bytes.withUnsafeBytes { ptr in
            var written = 0
            while written < bytes.count {
                let n = Darwin.send(fd, ptr.baseAddress!.advanced(by: written), bytes.count - written, 0)
                if n <= 0 { return }
                written += n
            }
        }
    }

    func close() { Darwin.close(fd) }
}

final class Daemon {
    let socketPath: String
    let idleSeconds: Double
    let lensEnabled: Bool

    private var listenFD: Int32 = -1
    private let connectionsLock = NSLock()
    private var connections = Set<ConnectionContextBox>()
    private var idleTimer: DispatchSourceTimer?
    private let connQueue = DispatchQueue(label: "agent-cu.conn", attributes: .concurrent)
    private let workQueue = DispatchQueue(label: "agent-cu.work", attributes: .concurrent)

    let elementStore = ElementStore()
    let appState = AppStateStore()

    init(socketPath: String, idleSeconds: Double, lensEnabled: Bool) {
        self.socketPath = socketPath
        self.idleSeconds = idleSeconds
        self.lensEnabled = lensEnabled
    }

    // Identity wrapper so Set<ConnectionContext> keys by object identity
    final class ConnectionContextBox: Hashable {
        let ctx: ConnectionContext
        init(_ c: ConnectionContext) { ctx = c }
        static func == (a: ConnectionContextBox, b: ConnectionContextBox) -> Bool { a.ctx === b.ctx }
        func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(ctx)) }
    }

    func run() {
        // Boot an NSApplication context so NSWorkspace launch/termination
        // notifications actually flow — without it runningApplications
        // stays a stale snapshot from process start.
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)

        signal(SIGPIPE, SIG_IGN)
        unlink(socketPath)

        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD >= 0 else {
            FileHandle.standardError.write("failed to create socket\n".data(using: .utf8)!)
            exit(1)
        }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            FileHandle.standardError.write("socket path too long\n".data(using: .utf8)!)
            exit(1)
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { p in
            p.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                _ = pathBytes.withUnsafeBufferPointer { src in
                    memcpy(dest, src.baseAddress!, src.count)
                }
            }
        }
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sp in
                Darwin.bind(listenFD, sp, addrLen)
            }
        }
        guard bindResult == 0, listen(listenFD, 16) == 0 else {
            FileHandle.standardError.write("bind/listen failed on \(socketPath): \(errno)\n".data(using: .utf8)!)
            exit(1)
        }
        chmod(socketPath, 0o600)

        armIdleTimer()
        let acceptQ = DispatchQueue(label: "agent-cu.accept")
        acceptQ.async { self.acceptLoop() }
        // NSApp.run() pumps the main runloop AND drains DispatchQueue.main —
        // required for PiP: NSPanel/SCStream and AX observers all live on the
        // main runloop, and DispatchQueue.main.sync blocks submitted from
        // worker threads must actually execute on the main thread.
        NSApp.run()
    }

    private func armIdleTimer() {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        idleTimer?.cancel()
        guard connections.isEmpty, idleSeconds > 0 else { return }
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        t.schedule(deadline: .now() + idleSeconds)
        t.setEventHandler { exit(0) }
        idleTimer = t
        t.resume()
    }

    private func acceptLoop() {
        while true {
            let fd = accept(listenFD, nil, nil)
            if fd < 0 { continue }
            let ctx = ConnectionContext(fd: fd)
            connectionsLock.lock()
            connections.insert(ConnectionContextBox(ctx))
            idleTimer?.cancel()
            connectionsLock.unlock()
            connQueue.async { self.readLoop(ctx) }
        }
    }

    private func dropConnection(_ ctx: ConnectionContext) {
        connectionsLock.lock()
        connections.remove(ConnectionContextBox(ctx))
        connectionsLock.unlock()
        ctx.close()
        armIdleTimer()
    }

    private func readLoop(_ ctx: ConnectionContext) {
        var buf = [UInt8](repeating: 0, count: 65536)
        while true {
            let n = recv(ctx.fd, &buf, buf.count, 0)
            if n <= 0 { break }
            ctx.readBuffer.append(buf, count: n)
            while let nl = ctx.readBuffer.firstIndex(of: 0x0A) {
                let lineData = ctx.readBuffer.subdata(in: 0..<nl)
                ctx.readBuffer.removeSubrange(0...nl)
                guard !lineData.isEmpty,
                      let line = String(data: lineData, encoding: .utf8) else { continue }
                workQueue.async { self.handleLine(line, on: ctx) }
            }
            if ctx.readBuffer.count > 8 * 1024 * 1024 {
                ctx.readBuffer.removeAll() // oversized garbage frame; drop
            }
        }
        dropConnection(ctx)
    }

    private func handleLine(_ line: String, on ctx: ConnectionContext) {
        guard let req = WireRequest.parse(line) else {
            ctx.send(WireResponse.fail(id: "", DaemonError("invalid_arg", "malformed request frame")))
            return
        }
        do {
            let data = try dispatch(cmd: req.cmd, args: req.args, ctx: ctx)
            ctx.send(WireResponse.ok(id: req.id, data: data))
        } catch {
            ctx.send(WireResponse.fail(id: req.id, DaemonError.wrap(error)))
        }
    }

    // MARK: - dispatch table (45 cmds per .164 contract; v1 implements the MCP-reachable subset)

    func dispatch(cmd: String, args: JSONDict, ctx: ConnectionContext) throws -> JSONDict {
        switch cmd {
        // infra
        case "ping": return try cmdPing(args)
        case "permissions": return try cmdPermissions(args)
        case "grant": return try cmdGrant(args)
        case "shutdown": return try cmdShutdown(args)
        // inventory
        case "apps": return try cmdApps(args)
        case "list_apps": return try cmdListApps(args)
        case "windows": return try cmdWindows(args)
        // snapshot
        case "snap": return try cmdSnap(args)
        case "get_app_state": return try cmdGetAppState(args)
        // launch
        case "launch_app": return try cmdLaunchApp(args)
        // actions
        case "click": return try cmdClick(args)
        case "perform_secondary_action": return try cmdSecondaryAction(args)
        case "drag": return try cmdDrag(args)
        case "type", "type_text": return try cmdTypeText(args)
        case "press": return try cmdPress(args)
        case "press_key": return try cmdPressKey(args)
        case "set_value": return try cmdSetValue(args)
        case "select_text": return try cmdSelectText(args)
        case "scroll": return try cmdScroll(args)
        // capture
        case "shot": return try cmdShot(args)
        case "shot_display": return try cmdShotDisplay(args)

        // picture-in-picture
        case "pip_open": return try cmdPipOpen(args)
        case "pip_close": return try cmdPipClose(args)
        case "pip_status": return try cmdPipStatus(args)
        case "pip_arm": return try cmdPipArm(args)
        case "pip_disarm": return try cmdPipDisarm(args)

        // Full-surface commands present in Alma's dispatch but outside this
        // build's implemented subset. Named explicitly so they are NOT
        // mistaken for unknown commands (Alma returns invalid_arg/unknown cmd
        // only for names outside the table).
        case "open_url", "intent", "lens",
             "mcp_start", "mcp_stop", "mcp_status", "mcp_allow", "mcp_deny_all",
             "mcp_whitelist", "mcp_arm_peer", "raise", "remote_input",
             "stealth_stats", "turn_ended",
             "appshot_monitor_start", "appshot_monitor_stop",
             "appshot_frontmost", "appshot_capture":
            throw DaemonError("not_implemented",
                "cmd '\(cmd)' is part of the Alma surface but not implemented in this build")
        default:
            throw DaemonError("invalid_arg", "unknown cmd: \(cmd)")
        }
    }

    /// Broadcast an event frame to every connection subscribed to `topic`.
    func broadcast(topic: String, payload: JSONDict) {
        connectionsLock.lock()
        let conns = connections
        connectionsLock.unlock()
        let frame = WireResponse.evt(topic: topic, payload: payload)
        for box in conns where box.ctx.subscriptions.contains(topic) {
            box.ctx.send(frame)
        }
    }
}
