import Foundation

struct SQLFormatter {
    static func format(_ sql: String) -> String {
        guard !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return sql }

        var result = sql

        result = uppercaseKeywords(result)
        result = indentClauses(result)
        result = normalizeSpacing(result)

        return result
    }

    private static let keywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "IS", "NULL",
        "AS", "ON", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "FULL", "CROSS",
        "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "FULL JOIN", "CROSS JOIN",
        "ORDER BY", "GROUP BY", "HAVING", "LIMIT", "OFFSET",
        "INSERT INTO", "VALUES", "UPDATE", "SET", "DELETE FROM",
        "CREATE", "TABLE", "ALTER", "ADD", "DROP", "COLUMN", "INDEX",
        "PRIMARY KEY", "FOREIGN KEY", "REFERENCES", "CONSTRAINT",
        "UNIQUE", "CHECK", "DEFAULT", "CASCADE", "RESTRICT",
        "BEGIN", "COMMIT", "ROLLBACK", "TRANSACTION",
        "UNION", "ALL", "INTERSECT", "EXCEPT",
        "DISTINCT", "TOP", "CASE", "WHEN", "THEN", "ELSE", "END",
        "EXISTS", "BETWEEN", "LIKE", "ILIKE", "IN",
        "ASC", "DESC", "NULLS FIRST", "NULLS LAST",
        "WITH", "RECURSIVE", "RETURNING",
        "EXPLAIN", "ANALYZE", "TRUNCATE",
        "VIEW", "MATERIALIZED", "FUNCTION", "PROCEDURE", "TRIGGER", "SEQUENCE",
    ]

    private static func uppercaseKeywords(_ sql: String) -> String {
        var result = sql
        let pattern = try! NSRegularExpression(pattern: "\\b([a-zA-Z_]+)\\b")
        let range = NSRange(result.startIndex..., in: result)
        let matches = pattern.matches(in: result, range: range)

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let word = String(result[range])
            let upper = word.uppercased()
            if keywords.contains(upper) {
                result.replaceSubrange(range, with: upper)
            }
        }
        return result
    }

    private static func indentClauses(_ sql: String) -> String {
        let lines = sql.components(separatedBy: "\n")
        var formatted: [String] = []
        var indentLevel = 0

        let indentKeywords: Set<String> = ["SELECT", "FROM", "WHERE", "ORDER BY", "GROUP BY", "HAVING",
                                             "LIMIT", "OFFSET", "INSERT INTO", "UPDATE", "SET", "DELETE FROM"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let upper = trimmed.uppercased().trimmingCharacters(in: .whitespaces)

            if upper.hasPrefix(")") {
                indentLevel = max(0, indentLevel - 1)
            }

            var indent = ""
            if indentLevel > 0 {
                indent = String(repeating: "  ", count: indentLevel)
            }

            for keyword in indentKeywords {
                if upper.hasPrefix(keyword) && !upper.hasPrefix("AND") && !upper.hasPrefix("OR") && indentLevel == 0 {
                    if keyword == "SELECT" {
                        formatted.append(indent + trimmed)
                    } else {
                        if !formatted.isEmpty {
                            formatted.append("")
                        }
                        formatted.append(indent + trimmed)
                    }
                    indentLevel = 1
                    break
                }
            }

            if upper.hasPrefix("(") {
                indentLevel += 1
            }

            if indentLevel > 0 && !upper.hasPrefix("SELECT") && !upper.hasPrefix("--") {
                formatted.append(indent + trimmed)
            } else if !upper.hasPrefix("SELECT") {
                formatted.append(indent + trimmed)
            }
        }

        return formatted.joined(separator: "\n")
    }

    private static func normalizeSpacing(_ sql: String) -> String {
        var result = sql
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s*,\\s*", with: ", ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s*=\\s*", with: " = ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s*>\\s*", with: " > ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s*<\\s*", with: " < ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s*\\(\\s*", with: " (", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\s*\\)\\s*", with: ") ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespaces)
    }
}
