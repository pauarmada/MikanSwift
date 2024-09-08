//
//  MikanJs.swift
//  MikanSwift
//
//  Created by pauarmada on 2024/09/07.
//

import Foundation

// Port of mikan.js https://github.com/trkbt10/mikan.js
// mikan.js provides a solution to the word break problem by using simple morphological analysis with regular expressions.
public class MikanJs {
    
    enum WordType {
        case unknown
        case number
        case unit
        case bracketBegin
        case bracketEnd
        case keyword
    }
    
    private static let joshi = try! NSRegularExpression(
        pattern:
            "(でなければ|について|かしら|くらい|けれど|なのか|ばかり|ながら|ことよ|こそ" +
            "|こと|さえ|しか|した|たり|だけ|だに|だの|つつ|ても|てよ|でも|とも|から|な" +
            "ど|なり|ので|のに|ほど|まで|もの|やら|より|って|で|と|な|に|ね|の|も|は|" +
            "ば|へ|や|わ|を|か|が|さ|し|ぞ|て)",
        options: []
    )
    
    private static let numbers = try! NSRegularExpression(
        pattern: "([0-9０-９零一二三四五六七八九十]+)",
        options: []
    
    )
    
    private static let keywords = try! NSRegularExpression(
        pattern:
            "(\\&nbsp;|[a-zA-Z0-9]+\\.[a-z]{2,}|[一-龠々〆ヵヶゝ]+|[ぁ-んゝ]" +
            "+|[ァ-ヴー]+|[a-zA-Z0-9]+|[ａ-ｚＡ-Ｚ０-９]+)",
        options: []
    )
    
    private static let bracketsBegin = try! NSRegularExpression(
        pattern: "([〈《「『｢（(\\[【〔〚〖〘❮❬❪❨(<{❲❰｛❴])",
        options: []
    )
    
    private static let bracketsEnd = try! NSRegularExpression(
        pattern: "([〉》」』｣)）\\]】〕〗〙〛}>\\)❩❫❭❯❱❳❵｝])",
        options: []
    )

    private static let periods = try! NSRegularExpression(
        pattern: "([\\.\\,。、！\\!？\\?]+)$",
        options: []
    )
    
    private static let units = try! NSRegularExpression(
        pattern:
            "(px|point|＄|\\$|€|￥|ノット|ユーロ|ドル|円|里|百|千|万|億|兆|京|㌫|％" +
            "|\\%|cm|m|km|㌢|㍍|㌖|センチメートル|メートル|キロ|キロメートル|°|度|ℓ|" +
            "リットル|mℓ|ミリリットル|マイル|フィート)",
        options: []
    )

    private static let particles = try! NSRegularExpression(pattern: "^[とのに]$", options: [])
    private static let hiragana = try! NSRegularExpression(pattern: "[ぁ-んゝ]+", options: [])
    
    private static let newLine = try! NSRegularExpression(pattern: "\n", options: [])
    
    // See function SimpleAnalyze(str)
    public static func split(_ string: String) -> [String] {
        guard !string.isEmpty else {
            return [""]
        }
        
        let words = string.split(regex: keywords)
            .reduce([]) { $0 + $1.split(regex: joshi) }
            .reduce([]) { $0 + $1.split(regex: numbers) }
            .reduce([]) { $0 + $1.split(regex: bracketsBegin) }
            .reduce([]) { $0 + $1.split(regex: bracketsEnd) }
        
            // Split the line breaks up so we can count individual lines
            .reduce([]) { $0 + $1.split(regex: newLine) }
            .compactMap { $0 }

        var result: [String] = []
        var prevType = WordType.unknown
        var prevWord = ""

        words.forEach { word in
            let periodToken = word.countMatches(regex: periods)
            let joshiToken = word.countMatches(regex: joshi)
            let isToken = periodToken > 0 || joshiToken > 0
            
            if word.countMatches(regex: numbers) > 0 {
                result.append(word)
                prevType = .number
                prevWord = word
                return
            }
            
            // 前が数字で、後ろが単位であれば数字と単位を結合する
            if word.countMatches(regex: units) > 0, prevType == .number {
                result[result.count - 1] += word
                prevType = .unit
                prevWord = word
                return
            }
            
            if word.countMatches(regex: bracketsBegin) > 0 {
                prevType = .bracketBegin
                prevWord = word
                return
            }
            
            if word.countMatches(regex: bracketsEnd) > 0 {
                result[result.count - 1] += word
                prevType = .bracketEnd
                prevWord = word
                return
            }
            
            var word = word
            if prevType == .bracketBegin {
                word = prevWord + word
                prevWord = ""
                prevType = .unknown
            }
            
            // すでに文字が入っている上で助詞が続く場合は結合する（[単語][て|を|に|は|など]の形にする）
            if result.count > 0, isToken, prevType == .unknown {
                result[result.count - 1] += word
                prevType = .keyword
                prevWord = word
                return
            }
            
            // 単語のあとの文字がひらがななら結合する
            if result.count > 1 && isToken ||
                (prevType == .keyword &&
                 prevWord.countMatches(regex: particles) == 0 &&
                 prevWord.countMatches(regex: periods) == 0 &&
                 word.countMatches(regex: hiragana) > 0) {
                result[result.count - 1] += word
                if joshiToken == 0 {
                    prevType = .unknown
                }
                prevWord = word
                return
            }
            
            result.append(word)
            prevType = .keyword
            prevWord = word
        }

        return result
    }
}

private extension String {
    func countMatches(regex: NSRegularExpression) -> Int {
        regex.numberOfMatches(in: self, range: NSRange(location: 0, length: self.count))
    }
    
    // Get the list of ranges inside the string for the actual matches for the regex
    func matchRanges(regex: NSRegularExpression) -> [NSRange] {
        regex
            .matches(in: self, range: NSRange(location: 0, length: self.count))
            .map { $0.range }
    }
    
    func split(regex: NSRegularExpression) -> [String] {
        let matchRanges = matchRanges(regex: regex)
        
        // The above ranges are only for matches, we now insert the ranges for the the non-matches
        var previousEnd = 0
        var allRanges = matchRanges.reduce([]) { partial, range -> [NSRange] in
            var mutable = partial
            if (range.location != previousEnd) {
                mutable.append(NSRange(location: previousEnd, length: range.location - previousEnd))
            }
            mutable.append(range)
            previousEnd = range.location + range.length
            return mutable
        }
        
        // Append the last non-match
        if previousEnd != self.count {
            allRanges.append(NSRange(location: previousEnd, length: self.count - previousEnd))
        }
        
        // Transform the ranges to the actual substrings
        return allRanges.map { (self as NSString).substring(with: $0) }
    }
}
