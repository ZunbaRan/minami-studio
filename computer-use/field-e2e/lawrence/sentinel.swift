import AppKit
import CoreGraphics
let app = NSWorkspace.shared.frontmostApplication
let mouse = CGEvent(source: nil)?.location ?? .zero
let windows = CGWindowListCopyWindowInfo([.optionIncludingWindow], 234415) as? [[String:Any]] ?? []
let result: [String:Any] = ["front_pid": app?.processIdentifier ?? 0, "front_bundle": app?.bundleIdentifier ?? "", "cursor": ["x":mouse.x,"y":mouse.y], "target_window": windows]
if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), let string = String(data:data,encoding:.utf8) { print(string) }
