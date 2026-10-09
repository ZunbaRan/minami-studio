import Foundation

// CLI surface — verbatim live probe of AlmaComputerUse.bin 0.1.0:
//   version            → "alma-computer-use 0.1.0" (stdout, exit 0)
//   --help/-h/help and `daemon --help` → usage text (stdout, exit 0)
//   unknown subcommand → "unknown subcommand: X" on STDERR + usage on
//                        STDOUT, exit 2
//   daemon             → --socket PATH --idle-seconds N --lens/--no-lens;
//                        unknown flags & extra positionals ignored;
//                        idle default 900s actual (help text still says
//                        600 — kept verbatim)

let HELPER_VERSION = "0.1.0"
let DEFAULT_IDLE_SECONDS: Double = 900

func defaultSocketPath() -> String {
    let base = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/minami-studio")
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    return base.appendingPathComponent("computer-use.sock").path
}

/// Usage text — byte-for-byte from `alma-computer-use --help`.
func printUsage() {
    let text = """
    MinamiComputerUse — macOS desktop automation helper (AX + ScreenCaptureKit)

    Subcommands:
      daemon [--socket PATH] [--idle-seconds N]
          Start the long-running daemon. Opens a Unix domain socket and serves
          NDJSON requests. Exits after N seconds of inactivity (default 600).

      version
          Print version and exit.

    The daemon is normally launched automatically by the Minami app. Users do
    not need to run it directly.
    """
    FileHandle.standardOutput.write((text + "\n").data(using: .utf8)!)
}

let argv = CommandLine.arguments
let sub = argv.count > 1 ? argv[1] : "daemon"

switch sub {
case "version", "--version", "-v":
    FileHandle.standardOutput.write(
        "minami-studio \(HELPER_VERSION)\n".data(using: .utf8)!)
    exit(0)
case "help", "--help", "-h":
    printUsage()
    exit(0)
case "daemon":
    var socketPath = defaultSocketPath()
    var idleSeconds = DEFAULT_IDLE_SECONDS
    var lens = false
    var hideHWCursor = false
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
        case "--pip-hide-hw-cursor":
            hideHWCursor = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            break // unknown daemon flags & positionals are ignored
        }
        i += 1
    }
    Daemon(socketPath: socketPath, idleSeconds: idleSeconds, lensEnabled: lens,
           pipHideHWCursor: hideHWCursor).run()
default:
    FileHandle.standardError.write(
        "unknown subcommand: \(sub)\n".data(using: .utf8)!)
    printUsage()
    exit(2)
}
