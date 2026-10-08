import Foundation

// CLI surface — semantics per computer-use/chapters/12 ("native CLI 与前置 gate"):
//   no args            → daemon (default)
//   version/-v/--version → prints helper version 0.1.0 (independent of host version)
//   help/-h/--help     → usage
//   daemon             → --socket PATH --idle-seconds N --lens --no-lens
//                        unknown flags ignored; last --lens/--no-lens wins;
//                        idle default 900s (actual; help text may still say 600)
//   unknown subcommand → exit 2

let HELPER_VERSION = "0.1.0"
let DEFAULT_IDLE_SECONDS: Double = 900

func defaultSocketPath() -> String {
    let base = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/agent-computer-use")
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base.appendingPathComponent("computer-use.sock").path
}

func printUsage() {
    let text = """
    agent-computer-use \(HELPER_VERSION)
    Usage:
      agent-computer-use daemon --socket <path> [--idle-seconds <n>] [--lens|--no-lens]
      agent-computer-use version
      agent-computer-use help
    """
    FileHandle.standardOutput.write((text + "\n").data(using: .utf8)!)
}

let argv = CommandLine.arguments
let sub = argv.count > 1 ? argv[1] : "daemon"

switch sub {
case "version", "--version", "-v":
    FileHandle.standardOutput.write("\(HELPER_VERSION)\n".data(using: .utf8)!)
    exit(0)
case "help", "--help", "-h":
    printUsage()
    exit(0)
case "daemon":
    var socketPath = defaultSocketPath()
    var idleSeconds = DEFAULT_IDLE_SECONDS
    var lens = false
    var i = 2
    while i < argv.count {
        let flag = argv[i]
        switch flag {
        case "--socket":
            if i + 1 < argv.count { socketPath = argv[i + 1]; i += 1 }
        case "--idle-seconds":
            if i + 1 < argv.count, let v = Double(argv[i + 1]) { idleSeconds = v; i += 1 }
        case "--lens":
            lens = true
        case "--no-lens":
            lens = false
        default:
            break // unknown daemon flags are ignored
        }
        i += 1
    }
    Daemon(socketPath: socketPath, idleSeconds: idleSeconds, lensEnabled: lens).run()
default:
    FileHandle.standardError.write("unknown subcommand: \(sub)\n".data(using: .utf8)!)
    exit(2)
}
