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

/// Alma's emergency frame when JSONSerialization fails to encode a response:
/// a fixed id-less error envelope (verbatim).
private let encodeFailureLiteral =
    "{\"ok\":false,\"error\":{\"code\":\"internal\",\"message\":\"encode failure\"}}"

func jsonString(_ value: Any) -> String {
    let sanitised = jsonSanitise(value)
    guard let data = try? JSONSerialization.data(withJSONObject: sanitised, options: [.sortedKeys, .withoutEscapingSlashes]) else {
        return encodeFailureLiteral
    }
    return String(data: data, encoding: .utf8) ?? encodeFailureLiteral
}

// MARK: - Args accessors (daemon commands read loosely-typed dict args)

/// Alma's requireStr: missing, null, wrong type, OR empty all produce
/// `invalid_arg` with `missing "<key>"`. Plain `str()` keeps empty strings.
func requireStr(_ a: JSONDict, _ key: String) throws -> String {
    guard let s = a[key] as? String, !s.isEmpty else {
        throw DaemonError("invalid_arg", "missing \"\(key)\"")
    }
    return s
}

extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? { self[key] as? String }
    func str(_ key: String) -> String? {
        self[key] as? String
    }
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

    /// Alma maps non-CUError throws to `internal` + localizedDescription.
    static func wrap(_ e: Error) -> DaemonError {
        if let de = e as? DaemonError { return de }
        return DaemonError("internal", e.localizedDescription)
    }
}

// MARK: - Wire frames

struct WireRequest {
    let id: String
    let cmd: String
    let args: JSONDict

    /// Alma decodes the frame with JSONDecoder against a {id:String,
    /// cmd:String, args:Dictionary?} Codable. Failures reply with id "?" and
    /// `malformed JSON: <DecodingError.localizedDescription>` — so we decode
    /// through the real JSONDecoder to inherit Foundation's exact wording.
    private struct RequestHead: Decodable {
        let id: String
        let cmd: String
    }

    /// Failure carries only the Foundation wording — the handler adds the
    /// `malformed JSON: ` prefix itself.
    struct Malformed: Error { let message: String }

    static func parse(_ line: String) -> Result<WireRequest, Malformed> {
        guard let data = line.data(using: .utf8) else {
            return .failure(Malformed(message: "The data couldn't be read because it isn't in the correct format."))
        }
        let head: RequestHead
        do {
            head = try JSONDecoder().decode(RequestHead.self, from: data)
        } catch {
            return .failure(Malformed(message: error.localizedDescription))
        }
        // args: optional dictionary. A present non-dict produces the same
        // typeMismatch wording Foundation emits for [String: Any] fields.
        var args: JSONDict = [:]
        if let raw = try? JSONSerialization.jsonObject(with: data) as? JSONDict,
           let a = raw["args"], !(a is NSNull) {
            guard let d = a as? JSONDict else {
                return .failure(Malformed(message: "Expected to decode Dictionary<String, Any> but found \(jsonTypeWord(a)) instead."))
            }
            args = d
        }
        return .success(WireRequest(id: head.id, cmd: head.cmd, args: args))
    }

    /// Foundation JSONDecoder typeMismatch wording: "found a <word> instead".
    private static func jsonTypeWord(_ v: Any) -> String {
        switch v {
        case is String: return "a string"
        case is [Any]: return "an array"
        case is [String: Any]: return "a dictionary"
        case let n as NSNumber where CFGetTypeID(n) == CFBooleanGetTypeID(): return "a boolean"
        case is NSNumber: return "a number"
        case is NSNull: return "null"
        default: return "a value"
        }
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
