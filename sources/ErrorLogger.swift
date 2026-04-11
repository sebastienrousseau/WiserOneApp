// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//
//  ErrorLogger.swift
//  The Wiser One
//
//  Created by Sebastien Rousseau on 27/01/2024.
//

import Foundation

/// A singleton class responsible for logging errors throughout the application.
/// It provides a standardized way to log errors to a file.
class ErrorLogger {
    static let shared = ErrorLogger()
    private static let maxLogEntryLength = 8_192
    private let fileManager = FileManager.default
    private lazy var logURL: URL? = {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("appLog.txt")
    }()
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private init() {}

    /// Logs an error with detailed information including timestamp, error code, message, file, and method.
    /// - Parameters:
    ///   - error: The error to be logged.
    ///   - errorCode: An optional error code associated with the error.
    ///   - file: The file in which the error occurred.
    ///   - method: The method in which the error occurred.
    func logError(_ error: Error, errorCode: Int? = nil, file: String = #file, method: String = #function) {
        assert(!file.isEmpty, "File metadata must not be empty.")
        assert(!method.isEmpty, "Method metadata must not be empty.")
        let timestamp = Self.timestampFormatter.string(from: Date())
        let logString = buildLogString(
            timestamp: timestamp,
            error: error,
            errorCode: errorCode,
            file: file,
            method: method
        )
        logToFile(logString: logString)
    }

    private func buildLogString(
        timestamp: String,
        error: Error,
        errorCode: Int?,
        file: String,
        method: String
    ) -> String {
        let errorDescription = error.localizedDescription
        let codeDescription = errorCode.map { "Code: \($0) - " } ?? ""
        let fileDescription = "File: \(file) - "
        let methodDescription = "Method: \(method) - "
        let logString = "\(timestamp) - \(codeDescription)\(fileDescription)\(methodDescription)Error: \(errorDescription)\n"
        let bounded = String(logString.prefix(Self.maxLogEntryLength))
        assert(!bounded.isEmpty, "Generated log entry must not be empty.")
        return bounded
    }

    private func logToFile(logString: String) {
        assert(!logString.isEmpty, "Log writes require non-empty content.")
        assert(logString.count <= Self.maxLogEntryLength, "Log entry exceeds upper bound.")
        guard let logURL else {
            return
        }

        do {
            // Check if file exists
            if !fileManager.fileExists(atPath: logURL.path) {
                // Create a new file if it doesn't exist
                try logString.write(to: logURL, atomically: true, encoding: .utf8)
            } else {
                // If the file exists, append new content
                let fileHandle = try FileHandle(forWritingTo: logURL)
                defer { try? fileHandle.close() }
                try fileHandle.seekToEnd()
                if let data = logString.data(using: .utf8) {
                    try fileHandle.write(contentsOf: data)
                }
            }
        } catch {
            print("Unable to log to file: \(error)")
        }
    }
}
