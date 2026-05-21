import Foundation

@MainActor
public class SSHTunnelService {
    private var tunnelProcesses: [String: Process] = [:]
    private var tunnelPorts: [String: Int] = [:]

    public func startTunnel(configID: String, sshConfig: SSHConfig, remoteHost: String, remotePort: Int) async throws -> Int {
        stopTunnel(configID: configID)

        let localPort = findAvailablePort()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

        var args: [String] = [
            "-N",
            "-L", "\(localPort):\(remoteHost):\(remotePort)",
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ExitOnForwardFailure=yes",
            "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3",
        ]

        if sshConfig.authMethod == .key {
            args.append("-o")
            args.append("PasswordAuthentication=no")
            args.append("-o")
            args.append("PreferredAuthentications=publickey")
            if let keyPath = sshConfig.keyPath, !keyPath.isEmpty {
                args.append("-i")
                args.append(keyPath)
            }
        } else {
            args.append("-o")
            args.append("PasswordAuthentication=yes")
            args.append("-o")
            args.append("PreferredAuthentications=password")
        }

        args.append("-p")
        args.append("\(sshConfig.port)")
        args.append("\(sshConfig.user)@\(sshConfig.host)")

        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        tunnelProcesses[configID] = process
        tunnelPorts[configID] = localPort

        try await Task.sleep(nanoseconds: 1_500_000_000)

        if process.isRunning {
            return localPort
        }

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errMsg = String(data: errData, encoding: .utf8) ?? "Unknown error"

        stopTunnel(configID: configID)

        if sshConfig.authMethod == .password {
            throw SSHTunnelError.authenticationFailed
        }
        throw SSHTunnelError.connectionFailed(errMsg)
    }

    public func tunnelPort(for configID: String) -> Int? {
        tunnelPorts[configID]
    }

    public func stopTunnel(configID: String) {
        tunnelProcesses[configID]?.terminate()
        tunnelProcesses[configID] = nil
        tunnelPorts.removeValue(forKey: configID)
    }

    public func stopAll() {
        for (id, process) in tunnelProcesses {
            process.terminate()
            tunnelProcesses.removeValue(forKey: id)
            tunnelPorts.removeValue(forKey: id)
        }
    }

    private func findAvailablePort() -> Int {
        let startPort = 15432
        for port in startPort...(startPort + 100) {
            if !isPortInUse(port) {
                return port
            }
        }
        return startPort + Int.random(in: 0...100)
    }

    private func isPortInUse(_ port: Int) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-ti", "tcp:\(port)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

public enum SSHTunnelError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed
    case noSSHConfig

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg):
            return "SSH tunnel failed: \(msg)"
        case .authenticationFailed:
            return "SSH authentication failed. For password auth, install sshpass: brew install sshpass"
        case .noSSHConfig:
            return "No SSH configuration provided"
        }
    }
}
