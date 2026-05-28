import Cocoa

final class SyntaxHighlighter {
    let keywords: Set<String>
    private let hasHashComments: Bool

    init(language: String) {
        let lang = language.lowercased()
        self.keywords = Self.keywords(for: lang)
        self.hasHashComments = Self.hashCommentLanguages.contains(lang)
    }

    func highlight(_ textStorage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard fullRange.length > 0 else { return }

        textStorage.beginEditing()

        textStorage.removeAttribute(.foregroundColor, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: NSColor.textPrimary, range: fullRange)

        let text = textStorage.string

        var stringRanges: [NSRange] = []
        Self.stringDouble.findAll(in: text, range: fullRange, store: &stringRanges)
        Self.stringSingle.findAll(in: text, range: fullRange, store: &stringRanges)
        Self.stringBacktick.findAll(in: text, range: fullRange, store: &stringRanges)

        var commentRanges: [NSRange] = []
        Self.singleLineComment.findAll(in: text, range: fullRange, store: &commentRanges, excluding: stringRanges)
        Self.multiLineComment.findAll(in: text, range: fullRange, store: &commentRanges, excluding: stringRanges)
        Self.tripleDouble.findAll(in: text, range: fullRange, store: &commentRanges, excluding: stringRanges)
        Self.tripleSingle.findAll(in: text, range: fullRange, store: &commentRanges, excluding: stringRanges)
        if hasHashComments {
            Self.hashComment.findAll(in: text, range: fullRange, store: &commentRanges, excluding: stringRanges)
        }

        let excludedRanges = stringRanges + commentRanges

        Self.numberPattern.findAll(in: text, range: fullRange, excluding: excludedRanges) { range in
            textStorage.addAttribute(.foregroundColor, value: NSColor.syntaxNumber, range: range)
        }

        Self.typePattern.findAll(in: text, range: fullRange, excluding: excludedRanges) { range in
            textStorage.addAttribute(.foregroundColor, value: NSColor.syntaxType, range: range)
        }

        Self.functionPattern.enumerateMatches(in: text, range: fullRange) { result, _, _ in
            guard let range = result?.range(at: 1), !range.overlaps(excludedRanges) else { return }
            textStorage.addAttribute(.foregroundColor, value: NSColor.syntaxFunction, range: range)
        }

        if !keywords.isEmpty {
            let kwPattern = Self.buildKeywordPattern(keywords)
            kwPattern.findAll(in: text, range: fullRange, excluding: excludedRanges) { range in
                textStorage.addAttribute(.foregroundColor, value: NSColor.syntaxKeyword, range: range)
            }
        }

        for range in stringRanges {
            textStorage.addAttribute(.foregroundColor, value: NSColor.syntaxString, range: range)
        }

        for range in commentRanges {
            textStorage.addAttribute(.foregroundColor, value: NSColor.syntaxComment, range: range)
        }

        textStorage.endEditing()
    }

    // MARK: - Regex Patterns

    private static let stringDouble       = try! NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#, options: [])
    private static let stringSingle       = try! NSRegularExpression(pattern: #"'(?:[^'\\]|\\.)*'"#, options: [])
    private static let stringBacktick     = try! NSRegularExpression(pattern: #"`(?:[^`\\]|\\.)*`"#, options: [])
    private static let singleLineComment  = try! NSRegularExpression(pattern: #"//.*"#, options: [])
    private static let multiLineComment   = try! NSRegularExpression(pattern: #"/\*[\s\S]*?\*/"#, options: [])
    private static let hashComment        = try! NSRegularExpression(pattern: "#.*", options: [])
    private static let tripleDouble       = try! NSRegularExpression(pattern: ##""""[\s\S]*?""""""##, options: [])
    private static let tripleSingle       = try! NSRegularExpression(pattern: #"'''[\s\S]*?'''"#, options: [])
    private static let numberPattern      = try! NSRegularExpression(pattern: #"\b(?:0x[0-9a-fA-F]+|0b[01]+|\d+\.\d*(?:[eE][+-]?\d+)?|\d+)\b"#, options: [])
    private static let typePattern        = try! NSRegularExpression(pattern: #"\b[A-Z][a-zA-Z0-9_]*\b"#, options: [])
    private static let functionPattern    = try! NSRegularExpression(pattern: #"\b([a-zA-Z_][a-zA-Z0-9_]*)(?=\s*\()"#, options: [])

    private static func buildKeywordPattern(_ keywords: Set<String>) -> NSRegularExpression {
        let escaped = keywords.map { NSRegularExpression.escapedPattern(for: $0) }.sorted().joined(separator: "|")
        return try! NSRegularExpression(pattern: #"\b(?:\#(escaped))\b"#, options: [])
    }

    // MARK: - Keyword Sets

    private static func keywords(for language: String) -> Set<String> {
        switch language {
        case "swift":
            ["import", "let", "var", "func", "class", "struct", "enum", "protocol",
             "extension", "if", "else", "switch", "case", "default", "for", "while",
             "repeat", "do", "return", "break", "continue", "guard", "defer", "throw",
             "throws", "rethrows", "catch", "try", "as", "is", "where", "in", "of",
             "public", "private", "internal", "fileprivate", "open", "static", "final",
             "override", "required", "convenience", "lazy", "weak", "unowned",
             "mutating", "nonmutating", "indirect", "some", "any", "self", "super",
             "nil", "true", "false", "async", "await", "actor", "associatedtype",
             "inout", "noncopyable", "borrowing", "consuming", "precondition", "fatalError"]

        case "python":
            ["import", "from", "as", "def", "class", "return", "if", "elif", "else",
             "for", "while", "break", "continue", "pass", "raise", "try", "except",
             "finally", "with", "yield", "lambda", "and", "or", "not", "in", "is",
             "None", "True", "False", "self", "async", "await", "global", "nonlocal",
             "del", "assert", "match", "case"]

        case "javascript", "typescript":
            ["import", "from", "export", "default", "function", "class", "const",
             "let", "var", "return", "if", "else", "for", "while", "do", "switch",
             "case", "break", "continue", "new", "delete", "typeof", "instanceof",
             "this", "super", "null", "undefined", "true", "false", "try", "catch",
             "finally", "throw", "async", "await", "yield", "in", "of", "as",
             "interface", "type", "enum", "implements", "extends", "abstract",
             "private", "protected", "public", "static", "readonly", "declare",
             "namespace", "module", "keyof", "never", "unknown", "any", "void"]

        case "rust":
            ["fn", "let", "mut", "const", "static", "if", "else", "for", "while",
             "loop", "break", "continue", "return", "match", "use", "mod", "struct",
             "enum", "trait", "impl", "type", "pub", "crate", "self", "super",
             "true", "false", "Some", "None", "Ok", "Err", "as", "in", "where",
             "ref", "move", "async", "await", "unsafe", "extern", "macro_rules",
             "dyn", "abstract", "become", "box", "do", "final", "override",
             "priv", "typeof", "unsized", "virtual", "yield"]

        case "go":
            ["func", "type", "struct", "interface", "map", "chan", "var", "const",
             "if", "else", "for", "range", "switch", "case", "default", "break",
             "continue", "return", "go", "defer", "select", "fallthrough", "package",
             "import", "true", "false", "nil", "make", "new", "append", "len", "cap",
             "close", "delete", "panic", "recover", "print", "println"]

        case "java", "kotlin":
            ["import", "package", "class", "interface", "enum", "extends",
             "implements", "public", "private", "protected", "static", "final",
             "abstract", "synchronized", "volatile", "transient", "native",
             "if", "else", "for", "while", "do", "switch", "case", "default",
             "break", "continue", "return", "new", "this", "super", "null",
             "true", "false", "try", "catch", "finally", "throw", "throws",
             "instanceof", "void", "var", "val", "fun", "object", "when",
             "data", "sealed", "inner", "companion", "init", "open", "override",
             "lateinit", "inline", "infix", "operator", "tailrec", "suspend"]

        case "ruby":
            ["def", "class", "module", "if", "elsif", "else", "unless", "case",
             "when", "then", "for", "while", "until", "do", "end", "begin",
             "rescue", "ensure", "return", "break", "next", "redo", "retry",
             "yield", "self", "nil", "true", "false", "and", "or", "not",
             "in", "alias", "defined?", "require", "include", "extend", "prepend",
             "attr_accessor", "attr_reader", "attr_writer", "raise", "throw", "catch"]

        case "c", "cpp", "csharp", "c#":
            ["if", "else", "for", "while", "do", "switch", "case", "default",
             "break", "continue", "return", "goto", "typedef", "struct", "union",
             "enum", "class", "namespace", "using", "template", "typename",
             "public", "private", "protected", "virtual", "override", "static",
             "const", "constexpr", "extern", "volatile", "mutable", "explicit",
             "inline", "friend", "sizeof", "new", "delete", "try", "catch",
             "throw", "nullptr", "true", "false", "auto", "register", "signed",
             "unsigned", "int", "long", "short", "char", "float", "double",
             "void", "bool", "this", "virtual", "override", "sealed", "abstract",
             "readonly", "ref", "out", "in", "as", "is", "sizeof", "typeof",
             "nameof", "get", "set", "value", "var", "dynamic", "async", "await"]

        case "php":
            ["if", "else", "elseif", "for", "foreach", "while", "do", "switch",
             "case", "default", "break", "continue", "return", "function", "class",
             "interface", "trait", "namespace", "use", "require", "require_once",
             "include", "include_once", "new", "clone", "instanceof", "public",
             "private", "protected", "static", "abstract", "final", "const",
             "var", "global", "throw", "try", "catch", "finally", "null",
             "true", "false", "array", "echo", "print", "die", "exit", "isset",
             "unset", "empty", "self", "parent", "yield", "match", "fn",
             "readonly", "enum", "mixed", "never", "void", "iterable"]

        case "shell", "bash", "zsh":
            ["if", "then", "else", "elif", "fi", "for", "while", "until", "do",
             "done", "case", "esac", "in", "function", "return", "exit", "break",
             "continue", "export", "local", "readonly", "unset", "declare",
             "typeset", "alias", "echo", "printf", "read", "source", "set",
             "shift", "exec", "eval", "trap", "select", "true", "false"]

        case "yaml":
            ["true", "false", "yes", "no", "on", "off", "null", "~"]

        case "dockerfile", "docker":
            ["FROM", "RUN", "CMD", "ENTRYPOINT", "COPY", "ADD", "WORKDIR",
             "ENV", "ARG", "LABEL", "EXPOSE", "VOLUME", "USER", "SHELL",
             "HEALTHCHECK", "ONBUILD", "STOPSIGNAL", "MAINTAINER"]

        case "elixir":
            ["def", "defmodule", "defp", "defguard", "defmacro", "defmacrop",
             "if", "else", "elsif", "unless", "case", "cond", "for", "with",
             "do", "end", "true", "false", "nil", "fn", "when", "and", "or",
             "not", "in", "raise", "try", "rescue", "catch", "after",
             "import", "alias", "use", "require", "receive", "send",
             "spawn", "pid", "module", "struct", "protocol", "impl",
             "defimpl", "defprotocol", "defstruct", "defexception",
             "quote", "unquote", "super", "__MODULE__", "__MODULE__"]

        case "dart":
            ["import", "export", "library", "part", "class", "enum", "extends",
             "implements", "with", "mixin", "abstract", "base", "sealed",
             "final", "interface", "mixin", "on", "typedef", "var", "final",
             "const", "void", "int", "double", "num", "bool", "String",
             "dynamic", "Null", "Never", "void", "if", "else", "for", "while",
             "do", "switch", "case", "default", "break", "continue", "return",
             "try", "catch", "finally", "throw", "rethrow", "assert",
             "async", "await", "yield", "sync", "async*", "sync*",
             "true", "false", "null", "this", "super", "new", "is", "as",
             "show", "hide", "required", "factory", "covariant", "get", "set",
             "operator", "static", "external", "late", "override"]

        case "toml":
            ["true", "false"]

        case "scala":
            ["import", "package", "class", "object", "trait", "enum", "case",
             "extends", "with", "implements", "abstract", "sealed", "final",
             "private", "protected", "public", "override", "implicit",
             "def", "val", "var", "lazy", "type", "if", "else", "for",
             "while", "do", "match", "case", "return", "throw", "try",
             "catch", "finally", "new", "this", "super", "null", "true",
             "false", "yield", "forSome", "macro", "inline", "infix",
             "prefix", "postfix", "transparent"]

        case "lua":
            ["function", "local", "if", "then", "else", "elseif", "for",
             "while", "do", "repeat", "until", "end", "return", "break",
             "and", "or", "not", "in", "nil", "true", "false", "require",
             "module", "self", "type", "ipairs", "pairs", "print",
             "select", "unpack", "pcall", "xpcall", "error", "assert",
             "tostring", "tonumber", "rawset", "rawget", "next",
             "coroutine", "string", "table", "math", "io", "os"]

        case "perl":
            ["my", "our", "local", "state", "sub", "if", "else", "elsif",
             "unless", "for", "foreach", "while", "until", "do", "given",
             "when", "default", "return", "last", "next", "redo", "continue",
             "die", "warn", "say", "print", "open", "close", "use", "require",
             "package", "module", "our", "class", "extends", "implements",
             "true", "false", "undef", "split", "join", "shift", "unshift",
             "push", "pop", "map", "grep", "sort", "keys", "values", "each"]

        case "r":
            ["function", "if", "else", "for", "while", "repeat", "in",
             "next", "break", "return", "TRUE", "FALSE", "NULL", "NA",
             "Inf", "NaN", "library", "require", "source", "setwd",
             "getwd", "install.packages", "data.frame", "list",
             "c", "mean", "sum", "length", "nrow", "ncol", "names",
             "rownames", "colnames", "subset", "transform", "aggregate",
             "merge", "plot", "ggplot", "aes", "geom_point", "geom_line",
             "lm", "glm", "summary", "head", "tail", "str", "class",
             "typeof", "print", "cat", "paste", "paste0", "sprintf",
             "grep", "grepl", "sub", "gsub", "lapply", "sapply", "apply"]

        case "markdown":
            []

        case "sql":
            ["SELECT", "select", "FROM", "from", "WHERE", "where",
             "INSERT", "insert", "INTO", "into", "VALUES", "values",
             "UPDATE", "update", "SET", "set", "DELETE", "delete",
             "CREATE", "create", "TABLE", "table", "ALTER", "alter",
             "DROP", "drop", "INDEX", "index", "VIEW", "view",
             "JOIN", "join", "INNER", "inner", "LEFT", "left",
             "RIGHT", "right", "OUTER", "outer", "CROSS", "cross",
             "ON", "on", "AND", "and", "OR", "or", "NOT", "not",
             "IN", "in", "LIKE", "like", "BETWEEN", "between",
             "IS", "is", "NULL", "null", "AS", "as",
             "ORDER", "order", "BY", "by", "GROUP", "group",
             "HAVING", "having", "LIMIT", "limit", "OFFSET", "offset",
             "DISTINCT", "distinct", "UNION", "union", "ALL", "all",
             "EXISTS", "exists", "CASE", "case", "WHEN", "when",
             "THEN", "then", "ELSE", "else", "END", "end",
             "ASC", "asc", "DESC", "desc", "PRIMARY", "primary",
             "KEY", "key", "FOREIGN", "foreign", "REFERENCES", "references",
             "CONSTRAINT", "constraint", "DEFAULT", "default",
             "CHECK", "check", "UNIQUE", "unique",
             "BEGIN", "begin", "COMMIT", "commit", "ROLLBACK", "rollback",
             "GRANT", "grant", "REVOKE", "revoke"]

        default:
            []
        }
    }

    private static let hashCommentLanguages: Set<String> = [
        "python", "ruby", "shell", "bash", "zsh", "yaml", "toml", "perl", "r",
        "dockerfile", "docker", "elixir"
    ]
}

// MARK: - Foundation Extensions

private extension NSRange {
    func overlaps(_ ranges: [NSRange]) -> Bool {
        for r in ranges {
            if NSIntersectionRange(self, r).length > 0 {
                return true
            }
        }
        return false
    }
}

private extension NSRegularExpression {
    func findAll(in string: String, range: NSRange, store: inout [NSRange]) {
        enumerateMatches(in: string, range: range) { result, _, _ in
            guard let range = result?.range else { return }
            store.append(range)
        }
    }

    func findAll(in string: String, range: NSRange, store: inout [NSRange], excluding: [NSRange]) {
        enumerateMatches(in: string, range: range) { result, _, _ in
            guard let matchRange = result?.range, !matchRange.overlaps(excluding) else { return }
            store.append(matchRange)
        }
    }

    func findAll(in string: String, range: NSRange, excluding: [NSRange], apply: (NSRange) -> Void) {
        enumerateMatches(in: string, range: range) { result, _, _ in
            guard let matchRange = result?.range, !matchRange.overlaps(excluding) else { return }
            apply(matchRange)
        }
    }
}
