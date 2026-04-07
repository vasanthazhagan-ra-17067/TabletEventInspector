//
//  EventLogger.swift
//  TabletEventInspector
//
//  File writer: appends JSON Lines to ~/Library/Logs/TabletEventInspector/events.log
//

import Foundation

final class EventLogger {

    static let shared = EventLogger()

    private let logFileURL: URL
    private var fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.tabletinspector.logger", qos: .utility)

    private init() {
        let logsDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/TabletEventInspector", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        logFileURL = logsDir.appendingPathComponent("events.log")

        // Ensure the file exists before opening a FileHandle.
        // Data.write(to:options:.withoutOverwriting) creates the file atomically
        // if absent, and does nothing if it already exists.
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            try? Data().write(to: logFileURL, options: .withoutOverwriting)
        }
        do {
            fileHandle = try FileHandle(forWritingTo: logFileURL)
            fileHandle?.seekToEndOfFile()
        } catch {
            // Log to console so the error is visible during development
            print("[EventLogger] Failed to open log file: \(error)")
        }
    }

    func log(_ record: TabletEventRecord) {
        queue.async { [weak self] in
            guard let self else { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            guard let data = try? encoder.encode(record),
                  var line = String(data: data, encoding: .utf8) else { return }
            line += "\n"
            guard let lineData = line.data(using: .utf8) else { return }
            self.fileHandle?.write(lineData)
        }
    }

    /// Truncates the log file to zero bytes so the on-disk log stays in sync
    /// with the in-memory clear performed by EventLogStore.clear().
    func clearFile() {
        queue.async { [weak self] in
            guard let self else { return }
            // Truncate at offset 0 removes all content, then seek resets the
            // write pointer so subsequent log() calls start from the beginning.
            self.fileHandle?.truncateFile(atOffset: 0)
            self.fileHandle?.seek(toFileOffset: 0)
        }
    }

    var logFilePublicURL: URL { logFileURL }
}
