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

    private init() {}

    /// Logs an error with detailed information including timestamp, error code, message, file, and method.
    /// - Parameters:
    ///   - error: The error to be logged.
    ///   - errorCode: An optional error code associated with the error.
    ///   - file: The file in which the error occurred.
    ///   - method: The method in which the error occurred.
    func logError(_ error: Error, errorCode: Int? = nil, file: String = #file, method: String = #function) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())

        let errorDescription = error.localizedDescription
        let codeDescription = errorCode != nil ? "Code: \(errorCode!) - " : ""
        let fileDescription = "File: \(file) - "
        let methodDescription = "Method: \(method) - "

        let logString = "\(timestamp) - \(codeDescription)\(fileDescription)\(methodDescription)Error: \(errorDescription)\n"

        // Log to file
        logToFile(logString: logString)
    }

    private func logToFile(logString: String) {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let logURL = urls.first?.appendingPathComponent("appLog.txt") else {
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
                fileHandle.seekToEndOfFile()
                if let data = logString.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            }
        } catch {
            print("Unable to log to file: \(error)")
        }
    }
}
