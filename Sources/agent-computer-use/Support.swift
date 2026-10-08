import Foundation

// Wire types + helpers for the agent-computer-use daemon protocol.
// Spec: computer-use/chapters/12 (45-cmd dispatch), 03-daemon-protocol (envelope),
// code-evidence/* and alma-computer-use-archive for .153 branch semantics.

// MARK: - JSON value helpers

typealias JSONDict = [String: Any]

/// Run `body` on the main thread synchronously (daemon requests arrive on
/// worker threads; AppKit and some CG/CaptureKit paths are main-runloop-bound).
func onMainThread<T>(_ body: () throws -> T) throws -> T {
    if Thread.isMainThread { return try body() }
    var result: Result<T, Error>!
    DispatchQueue.main.sync { result = Result { try body() } }
    return try result.get()
}
func onMainThread<T>(_ body: () -> T) -> T {
    if Thread.isMainThread { return body() }
    return DispatchQueue.main.sync(execute: body)
}

/// Mirrors Alma's `jsonSanitise`: dictionaries/arrays are handled recursively,
/// primitives pass through, anything else falls back to `String(describing:)`.
func jsonSanitise(_ value: Any) -> Any {
    switch value {
    case let dict as [String: Any]:
        var out = JSONDict()
        for (k, v) in dict { out[k] = jsonSanitise(v) }
        return out
    case let dict as [AnyHashable: Any]:
        var out = JSONDict()
        for (k, v) in dict { out["\(k)"] = jsonSanitise(v) }
        return out
    case let arr as [Any]:
        return arr.map { jsonSanitise($0) }
    case let n as NSNumber:
        return n
    case let s as String:
        return s
    case is NSNull:
        return NSNull()
    default:
        if JSONSerialization.isValidJSONObject(value) { return value }
        return String(describing: value)
    }
}

func jsonString(_ value: Any) -> String {
    let sanitised = jsonSanitise(value)
    guard let data = try? JSONSerialization.data(withJSONObject: sanitised, options: [.sortedKeys, .withoutEscapingSlashes]) else {
        return "{}"
    }
    return String(data: data, encoding: .utf8) ?? "{}"
}

// MARK: - Args accessors (daemon commands read loosely-typed dict args)

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? { self[key] as? String }
    func bool(_ key: String) -> Bool? {
        if let b = self[key] as? Bool { return b }
        if let n = self[key] as? NSNumber { return n.boolValue }
        return nil
    }
    func int(_ key: String) -> Int? {
        if let n = self[key] as? NSNumber { return n.intValue }
        if let s = self[key] as? String { return Int(s) }
        return nil
    }
    func double(_ key: String) -> Double? {
        if let n = self[key] as? NSNumber { return n.doubleValue }
        if let s = self[key] as? String { return Double(s) }
        return nil
    }
    func dict(_ key: String) -> JSONDict? { self[key] as? JSONDict }
    func array(_ key: String) -> [Any]? { self[key] as? [Any] }
}

// MARK: - Errors (code+message+hint wire triple)

struct DaemonError: Error {
    let code: String
    let message: String
    let hint: String?

    init(_ code: String, _ message: String, hint: String? = nil) {
        self.code = code; self.message = message; self.hint = hint
    }

    var dict: JSONDict {
        var d: JSONDict = ["code": code, "message": message]
        if let hint { d["hint"] = hint }
        return d
    }

    static func wrap(_ e: Error) -> DaemonError {
        if let de = e as? DaemonError { return de }
        return DaemonError("internal_error", String(describing: e))
    }
}

// MARK: - Wire frames

struct WireRequest {
    let id: String
    let cmd: String
    let args: JSONDict

    static func parse(_ line: String) -> WireRequest? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? JSONDict,
              let cmd = obj["cmd"] as? String else { return nil }
        return WireRequest(
            id: obj["id"] as? String ?? "",
            cmd: cmd,
            args: obj["args"] as? JSONDict ?? [:]
        )
    }
}

enum WireResponse {
    static func ok(id: String, data: JSONDict) -> String {
        jsonString(["id": id, "ok": true, "data": data])
    }
    static func fail(id: String, _ e: DaemonError) -> String {
        jsonString(["id": id, "ok": false, "error": e.dict])
    }
    /// Server-pushed event frame: {"evt":true,"topic":...,"payload":{...}}
    static func evt(topic: String, payload: JSONDict) -> String {
        jsonString(["evt": true, "topic": topic, "payload": payload])
    }
}
