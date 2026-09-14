import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case json

    var id: String { rawValue }
    var title: String { self == .markdown ? "Markdown" : "JSON" }
    var fileExtension: String { self == .markdown ? "md" : "json" }
}

enum ExportRange: String, CaseIterable, Identifiable {
    case month
    case quarter
    case halfYear
    case year
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "חודש אחרון"
        case .quarter: return "רבעון אחרון"
        case .halfYear: return "חצי שנה"
        case .year: return "שנה"
        case .all: return "הכל"
        }
    }

    func start(from now: Date = .now) -> Date? {
        let cal = Calendar.current
        switch self {
        case .month: return cal.date(byAdding: .month, value: -1, to: now)
        case .quarter: return cal.date(byAdding: .month, value: -3, to: now)
        case .halfYear: return cal.date(byAdding: .month, value: -6, to: now)
        case .year: return cal.date(byAdding: .year, value: -1, to: now)
        case .all: return nil
        }
    }
}

/// The export never leaves the app on its own — it writes a file and hands it
/// to the system share sheet (US-E3).
enum Exporter {

    struct Result {
        let url: URL
        let includedCount: Int
        let excludedSensitiveCount: Int
    }

    static func export(
        entries: [Entry],
        range: ExportRange,
        format: ExportFormat,
        includeSensitive: Bool
    ) throws -> Result {
        let start = range.start()
        let inRange = entries
            .filter { start == nil || $0.createdAt >= start! }
            .sorted { $0.createdAt > $1.createdAt }

        let excluded = includeSensitive ? [] : inRange.filter(\.isSensitive)
        let included = includeSensitive ? inRange : inRange.filter { !$0.isSensitive }

        let text: String
        switch format {
        case .markdown:
            text = markdown(entries: included, range: range, excludedCount: excluded.count)
        case .json:
            text = try json(entries: included, range: range, excludedCount: excluded.count)
        }

        let stamp = ISO8601DateFormatter.filenameStamp.string(from: .now)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("maslul-\(stamp).\(format.fileExtension)")
        try text.write(to: url, atomically: true, encoding: .utf8)

        return Result(
            url: url,
            includedCount: included.count,
            excludedSensitiveCount: excluded.count
        )
    }

    // MARK: - Markdown

    private static func markdown(entries: [Entry], range: ExportRange, excludedCount: Int) -> String {
        var out = "# יומן מסלול\n\n"
        out += "טווח: \(range.title)  \n"
        out += "יוצא בתאריך: \(Fmt.longDate(.now))  \n"
        out += "רשומות: \(entries.count)  \n"
        // Never hide what was left out — a document that conceals its gaps is
        // not evidence (spec §07, US-B3).
        out += "רשומות רגישות שהוחרגו: \(excludedCount)\n\n"
        out += "---\n"

        var currentMonth = ""
        for entry in entries {
            let month = Fmt.monthYear(entry.createdAt)
            if month != currentMonth {
                currentMonth = month
                out += "\n## \(month)\n"
            }

            out += "\n### \(Fmt.longDate(entry.createdAt))\n"

            var meta: [String] = []
            if let type = entry.type { meta.append(type.title) }
            if let project = entry.project { meta.append(project.name) }
            if let origin = entry.effectiveOrigin { meta.append(origin.shortTitle) }
            if let effort = entry.effort { meta.append("מאמץ \(effort.title)") }
            if !meta.isEmpty { out += "_\(meta.joined(separator: " · "))_\n\n" }

            let legacy = entry.richTextDocument
            if legacy.isEmpty {
                out += "\(entry.body)\n"
            } else {
                out += "\(EntryRichTextMarkdown.render(entry.body, document: legacy))\n"
            }

            if !entry.attachmentNames.isEmpty {
                out += "\n\(entry.attachmentNames.count) קבצים מצורפים (נשארים במכשיר)\n"
            }
        }

        return out
    }

    // MARK: - JSON

    private struct EntryDTO: Encodable {
        let createdAt: Date
        let updatedAt: Date
        let type: String?
        let project: String?
        let origin: String?
        let effort: String?
        let sensitivity: String
        let attachmentCount: Int
        let body: String
        let richText: AttributedString?
    }

    private struct DocumentDTO: Encodable {
        let app = "maslul"
        let version = "0.1"
        let exportedAt: Date
        let range: String
        let entryCount: Int
        let excludedSensitiveCount: Int
        let note = "דיווח עצמי מקומי. הקובץ נוצר על המכשיר ולא נשלח לשום מקום."
        let entries: [EntryDTO]
    }

    private static func json(entries: [Entry], range: ExportRange, excludedCount: Int) throws -> String {
        let dtos = entries.map { entry in
            EntryDTO(
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt,
                type: entry.type?.rawValue,
                project: entry.project?.name,
                origin: entry.effectiveOrigin?.rawValue,
                effort: entry.effort?.rawValue,
                sensitivity: entry.sensitivity.rawValue,
                attachmentCount: entry.attachmentNames.count,
                body: entry.body,
                richText: entry.richTextData == nil ? nil : entry.attributedBody
            )
        }

        let document = DocumentDTO(
            exportedAt: .now,
            range: range.rawValue,
            entryCount: dtos.count,
            excludedSensitiveCount: excludedCount,
            entries: dtos
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(document)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Time allocation report (§11, US-G4)

extension Exporter {
    /// A standalone document for the range, with the weekly notes and the
    /// count of skipped weeks. A report that hides how many weeks are missing
    /// from it is not evidence.
    static func exportTimeReport(_ report: TimeReport, range: ExportRange) throws -> URL {
        var out = "# דוח הקצאת זמן\n\n"
        out += "טווח: \(range.title)  \n"
        out += "יוצא בתאריך: \(Fmt.longDate(.now))  \n"
        out += "שבועות שדווחו: \(report.recordedWeeks)  \n"
        out += "שבועות שדולגו: \(report.skippedWeeks)\n\n"
        out += "> \(TimeReport.disclaimer)\n\n---\n\n"

        out += "## לפי פרויקט\n\n"
        for line in report.lines {
            out += "- **\(line.project.name)** · \(Int(line.percent.rounded()))% · \(line.project.origin.title)\n"
        }

        out += "\n## לפי מקור המשימה\n\n"
        for item in report.originSplit {
            out += "- \(item.origin.title) · \(Int(item.percent.rounded()))%\n"
        }

        if !report.buckets.isEmpty {
            out += "\n## לפי תקופה\n"
            for bucket in report.buckets {
                out += "\n### \(bucket.label)\n"
                for line in report.lines {
                    let share = bucket.shares[line.id] ?? 0
                    guard share > 0 else { continue }
                    out += "- \(line.project.name): \(Int(share.rounded()))%\n"
                }
            }
        }

        if !report.notes.isEmpty {
            out += "\n## הערות שבועיות\n\n"
            for item in report.notes {
                out += "- \(Week.label(item.week)): \(item.note)\n"
            }
        }

        let stamp = ISO8601DateFormatter.filenameStamp.string(from: .now)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("maslul-time-\(stamp).md")
        try out.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

extension ISO8601DateFormatter {
    static let filenameStamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
        return f
    }()
}
