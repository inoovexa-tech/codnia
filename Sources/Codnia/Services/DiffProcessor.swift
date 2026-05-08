import Foundation

public struct DiffChunk: Identifiable {
    public let id = UUID()
    public let lines: [DiffLine]
    public let originalStart: Int
    public let modifiedStart: Int
    public let originalCount: Int
    public let modifiedCount: Int
}

enum DiffAlgorithm {
    case lcs
    case patience
}

public class DiffProcessor {
    
    /// Compute a side-by-side diff that pairs removed lines with added lines
    /// so they appear on the same visual row.
    public static func computeDiff(original: [String], modified: [String]) -> [DiffLine] {
        let rawDiff = lcsDiff(original: original, modified: modified)
        return pairLines(rawDiff)
    }
    
    // MARK: - Step 1: LCS raw diff
    
    private static func lcsDiff(original: [String], modified: [String]) -> [DiffLine] {
        let lcs = longestCommonSubsequence(original, modified)
        
        var result: [DiffLine] = []
        var oIdx = 0
        var mIdx = 0
        var lcsIdx = 0
        var originalLineNum = 1
        var modifiedLineNum = 1
        
        while oIdx < original.count || mIdx < modified.count {
            if lcsIdx < lcs.count {
                let lcsLine = lcs[lcsIdx]
                
                while oIdx < original.count && original[oIdx] != lcsLine {
                    result.append(DiffLine(
                        originalLine: original[oIdx],
                        modifiedLine: nil,
                        originalLineNumber: originalLineNum,
                        modifiedLineNumber: nil,
                        type: .removed
                    ))
                    originalLineNum += 1
                    oIdx += 1
                }
                
                while mIdx < modified.count && modified[mIdx] != lcsLine {
                    result.append(DiffLine(
                        originalLine: nil,
                        modifiedLine: modified[mIdx],
                        originalLineNumber: nil,
                        modifiedLineNumber: modifiedLineNum,
                        type: .added
                    ))
                    modifiedLineNum += 1
                    mIdx += 1
                }
                
                if oIdx < original.count && mIdx < modified.count {
                    result.append(DiffLine(
                        originalLine: original[oIdx],
                        modifiedLine: modified[mIdx],
                        originalLineNumber: originalLineNum,
                        modifiedLineNumber: modifiedLineNum,
                        type: .unchanged
                    ))
                    originalLineNum += 1
                    modifiedLineNum += 1
                    oIdx += 1
                    mIdx += 1
                    lcsIdx += 1
                }
            } else {
                while oIdx < original.count {
                    result.append(DiffLine(
                        originalLine: original[oIdx],
                        modifiedLine: nil,
                        originalLineNumber: originalLineNum,
                        modifiedLineNumber: nil,
                        type: .removed
                    ))
                    originalLineNum += 1
                    oIdx += 1
                }
                while mIdx < modified.count {
                    result.append(DiffLine(
                        originalLine: nil,
                        modifiedLine: modified[mIdx],
                        originalLineNumber: nil,
                        modifiedLineNumber: modifiedLineNum,
                        type: .added
                    ))
                    modifiedLineNum += 1
                    mIdx += 1
                }
            }
        }
        
        return result
    }
    
    // MARK: - Step 2: Pair removes/adds into single rows
    
    private static func pairLines(_ raw: [DiffLine]) -> [DiffLine] {
        var paired: [DiffLine] = []
        var i = 0
        
        while i < raw.count {
            let line = raw[i]
            
            // Collect consecutive removes
            if line.type == .removed {
                var removes: [DiffLine] = []
                var j = i
                while j < raw.count && raw[j].type == .removed {
                    removes.append(raw[j])
                    j += 1
                }
                
                // Collect consecutive adds
                var adds: [DiffLine] = []
                while j < raw.count && raw[j].type == .added {
                    adds.append(raw[j])
                    j += 1
                }
                
                // Pair up min(removes, adds) as .changed lines
                let pairCount = min(removes.count, adds.count)
                for k in 0..<pairCount {
                    paired.append(DiffLine(
                        originalLine: removes[k].originalLine,
                        modifiedLine: adds[k].modifiedLine,
                        originalLineNumber: removes[k].originalLineNumber,
                        modifiedLineNumber: adds[k].modifiedLineNumber,
                        type: .changed
                    ))
                }
                
                // Leftover removes (unpaired)
                for k in pairCount..<removes.count {
                    paired.append(removes[k])
                }
                
                // Leftover adds (unpaired)
                for k in pairCount..<adds.count {
                    paired.append(adds[k])
                }
                
                i = j
            } else {
                paired.append(line)
                i += 1
            }
        }
        
        return paired
    }
    
    // MARK: - LCS Algorithm
    
    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count
        
        guard m > 0 && n > 0 else { return [] }
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: 2)
        
        for i in 1...m {
            let current = i % 2
            let prev = (i - 1) % 2
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[current][j] = dp[prev][j - 1] + 1
                } else {
                    dp[current][j] = max(dp[prev][j], dp[current][j - 1])
                }
            }
        }
        
        var lcs: [String] = []
        var i = m
        var j = n
        
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                lcs.append(a[i - 1])
                i -= 1
                j -= 1
            } else if dp[(i - 1) % 2][j] >= dp[i % 2][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        
        return lcs.reversed()
    }
}
