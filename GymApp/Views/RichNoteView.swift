import SwiftUI

// MARK: - Note Link Detector

struct NoteLinkDetector {
    struct DetectedLink: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let url: URL
        let displayHost: String
        let isCustomTitle: Bool
    }

    static func parseLinksAndAttributedString(from text: String, accentColor: Color) -> (AttributedString, [DetectedLink]) {
        var detectedLinks: [DetectedLink] = []

        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // 1. Find markdown links: [Title](URL)
        let markdownRegexPattern = "\\[([^\\]]+)\\]\\((https?://[^\\s\\)]+|www\\.[^\\s\\)]+)\\)"
        guard let markdownRegex = try? NSRegularExpression(pattern: markdownRegexPattern, options: []) else {
            return (AttributedString(text), [])
        }

        let markdownMatches = markdownRegex.matches(in: text, options: [], range: fullRange)

        var coveredRanges: [NSRange] = []

        struct LinkSpan {
            let nsRange: NSRange
            let displayTitle: String
            let url: URL
            let isCustomTitle: Bool
        }

        var spans: [LinkSpan] = []

        for match in markdownMatches {
            let fullNsRange = match.range
            coveredRanges.append(fullNsRange)

            let titleNsRange = match.range(at: 1)
            let urlNsRange = match.range(at: 2)

            let titleStr = nsString.substring(with: titleNsRange)
            var urlStr = nsString.substring(with: urlNsRange)

            if urlStr.lowercased().hasPrefix("www.") {
                urlStr = "https://" + urlStr
            }

            if let url = URL(string: urlStr) {
                let host = url.host?.replacingOccurrences(of: "www.", with: "") ?? urlStr
                let link = DetectedLink(
                    title: titleStr,
                    url: url,
                    displayHost: host,
                    isCustomTitle: true
                )
                detectedLinks.append(link)

                spans.append(LinkSpan(
                    nsRange: fullNsRange,
                    displayTitle: titleStr,
                    url: url,
                    isCustomTitle: true
                ))
            }
        }

        // 2. Find raw URLs outside of markdown links
        if let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let rawMatches = dataDetector.matches(in: text, options: [], range: fullRange)
            for match in rawMatches {
                guard let matchUrl = match.url else { continue }
                let isInsideMarkdown = coveredRanges.contains { NSIntersectionRange($0, match.range).length > 0 }
                if !isInsideMarkdown {
                    coveredRanges.append(match.range)

                    let rawUrlText = nsString.substring(with: match.range)
                    let host = matchUrl.host?.replacingOccurrences(of: "www.", with: "") ?? rawUrlText
                    let link = DetectedLink(
                        title: host,
                        url: matchUrl,
                        displayHost: host,
                        isCustomTitle: false
                    )
                    detectedLinks.append(link)

                    spans.append(LinkSpan(
                        nsRange: match.range,
                        displayTitle: rawUrlText,
                        url: matchUrl,
                        isCustomTitle: false
                    ))
                }
            }
        }

        // Sort spans by start location
        spans.sort { $0.nsRange.location < $1.nsRange.location }

        // 3. Build AttributedString
        var result = AttributedString()
        var currentIndex = 0

        for span in spans {
            if span.nsRange.location > currentIndex {
                let plainNsRange = NSRange(location: currentIndex, length: span.nsRange.location - currentIndex)
                let plainSubstring = nsString.substring(with: plainNsRange)
                result.append(AttributedString(plainSubstring))
            }

            var linkAttrString = AttributedString(span.displayTitle)
            linkAttrString.link = span.url
            linkAttrString.foregroundColor = accentColor
            linkAttrString.underlineStyle = .single
            result.append(linkAttrString)

            currentIndex = span.nsRange.location + span.nsRange.length
        }

        if currentIndex < nsString.length {
            let remainingNsRange = NSRange(location: currentIndex, length: nsString.length - currentIndex)
            let remainingSubstring = nsString.substring(with: remainingNsRange)
            result.append(AttributedString(remainingSubstring))
        }

        return (result, detectedLinks)
    }

    static func extractLinks(from text: String) -> [DetectedLink] {
        return parseLinksAndAttributedString(from: text, accentColor: .accentColor).1
    }
}

// MARK: - Rich Note View

struct RichNoteView: View {
    let text: String
    var accentColor: Color = .accentColor
    var font: Font = .subheadline
    var foregroundColor: Color = .primary

    var body: some View {
        let (attributedText, links) = NoteLinkDetector.parseLinksAndAttributedString(from: text, accentColor: accentColor)

        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Formatted note text with inline links
                Text(attributedText)
                    .font(font)
                    .foregroundStyle(foregroundColor)
                    .fixedSize(horizontal: false, vertical: true)

                // Quick tap link buttons below text
                if !links.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(links) { link in
                            Link(destination: link.url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .foregroundStyle(accentColor)
                                    Text(link.title)
                                        .font(.caption.bold())
                                        .foregroundStyle(accentColor)
                                        .lineLimit(1)
                                    if !link.isCustomTitle {
                                        Text("(\(link.displayHost))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(accentColor.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}
