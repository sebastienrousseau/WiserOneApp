#!/usr/bin/env swift
import Foundation

struct CoverageSummary: Decodable {
    let count: Int
    let covered: Int
    let percent: Double
}

struct FileSummary: Decodable {
    let lines: CoverageSummary
    let regions: CoverageSummary
}

struct CoverageFile: Decodable {
    let filename: String
    let summary: FileSummary
}

struct CoverageData: Decodable {
    let files: [CoverageFile]
}

struct CoverageRoot: Decodable {
    let data: [CoverageData]
}

func usage() -> Never {
    fputs("Usage: check_coverage.swift <codecov-json-path> <min-percent> <include-subpath>\n", stderr)
    exit(2)
}

guard CommandLine.arguments.count >= 4 else {
    usage()
}

let jsonPath = CommandLine.arguments[1]
guard let minPercent = Double(CommandLine.arguments[2]) else {
    fputs("Invalid min-percent: \(CommandLine.arguments[2])\n", stderr)
    exit(2)
}
let includeSubpath = CommandLine.arguments[3]

let jsonURL = URL(fileURLWithPath: jsonPath)
let jsonData: Data

do {
    jsonData = try Data(contentsOf: jsonURL)
} catch {
    fputs("Failed to read coverage report at \(jsonPath): \(error)\n", stderr)
    exit(2)
}

let report: CoverageRoot
do {
    report = try JSONDecoder().decode(CoverageRoot.self, from: jsonData)
} catch {
    fputs("Failed to parse coverage report: \(error)\n", stderr)
    exit(2)
}

var lineCount = 0
var lineCovered = 0
var regionCount = 0
var regionCovered = 0
var matchedFiles = [String]()

for entry in report.data {
    for file in entry.files {
        let path = file.filename
        if !path.contains(includeSubpath) { continue }
        if path.contains("/.build/") { continue }
        if path.contains("/tests/") { continue }

        lineCount += file.summary.lines.count
        lineCovered += file.summary.lines.covered
        regionCount += file.summary.regions.count
        regionCovered += file.summary.regions.covered
        matchedFiles.append(path)
    }
}

guard lineCount > 0, regionCount > 0 else {
    fputs("No production coverage entries found for include path '\(includeSubpath)'.\n", stderr)
    exit(2)
}

let linePercent = (Double(lineCovered) / Double(lineCount)) * 100.0
let regionPercent = (Double(regionCovered) / Double(regionCount)) * 100.0

let lineFormatted = String(format: "%.2f", linePercent)
let regionFormatted = String(format: "%.2f", regionPercent)
print("Coverage scope: \(includeSubpath)")
print("Files matched: \(matchedFiles.count)")
print("Lines: \(lineCovered)/\(lineCount) (\(lineFormatted)%)")
print("Regions: \(regionCovered)/\(regionCount) (\(regionFormatted)%)")

if linePercent < minPercent || regionPercent < minPercent {
    fputs("Coverage gate failed. Minimum required is \(minPercent)% for lines and regions.\n", stderr)
    exit(1)
}

print("Coverage gate passed.")
