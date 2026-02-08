import SwiftUI

struct ChatBubble: View {
    let message: Message

    var isUser: Bool { message.role == .user }
    var shouldRenderMarkdown: Bool { message.role == .agent && !message.isStreaming }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Group {
                    if shouldRenderMarkdown {
                        MarkdownMessageView(content: message.content)
                    } else {
                        Text(message.content)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .if(isUser) { view in
                    view.foregroundStyle(.white)
                }

                if message.isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("streaming...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}

private struct MarkdownMessageView: View {
    let content: String

    private enum Block: Equatable {
        case heading(level: Int, text: String)
        case bullet(text: String)
        case paragraph(text: String)
        case code(language: String?, text: String)
        case spacer
    }

    private var blocks: [Block] {
        parseBlocks(from: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let text):
                    inlineText(text)
                        .font(level == 1 ? .title3.weight(.bold) : .headline)
                case .bullet(let text):
                    HStack(alignment: .top, spacing: 6) {
                        Text("-")
                        inlineText(text)
                    }
                case .paragraph(let text):
                    inlineText(text)
                case .code(let language, let text):
                    VStack(alignment: .leading, spacing: 6) {
                        if let language, !language.isEmpty {
                            Text(language)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(text)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                case .spacer:
                    Color.clear.frame(height: 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineText(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            return Text(attributed)
        }
        return Text(text)
    }

    private func parseBlocks(from input: String) -> [Block] {
        let lines = input.components(separatedBy: "\n")
        var result: [Block] = []
        var currentParagraph: [String] = []
        var inCodeBlock = false
        var codeLanguage: String?
        var codeLines: [String] = []

        func flushParagraph() {
            guard !currentParagraph.isEmpty else { return }
            result.append(.paragraph(text: currentParagraph.joined(separator: "\n")))
            currentParagraph.removeAll(keepingCapacity: true)
        }

        for rawLine in lines {
            let line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if inCodeBlock {
                if trimmed.hasPrefix("```") {
                    result.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
                    codeLines.removeAll(keepingCapacity: true)
                    codeLanguage = nil
                    inCodeBlock = false
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if trimmed.hasPrefix("```") {
                flushParagraph()
                let marker = trimmed.dropFirst(3)
                codeLanguage = marker.isEmpty ? nil : String(marker)
                inCodeBlock = true
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                if result.last != .spacer {
                    result.append(.spacer)
                }
                continue
            }

            if trimmed.hasPrefix("### ") {
                flushParagraph()
                result.append(.heading(level: 3, text: String(trimmed.dropFirst(4))))
                continue
            }

            if trimmed.hasPrefix("## ") {
                flushParagraph()
                result.append(.heading(level: 2, text: String(trimmed.dropFirst(3))))
                continue
            }

            if trimmed.hasPrefix("# ") {
                flushParagraph()
                result.append(.heading(level: 1, text: String(trimmed.dropFirst(2))))
                continue
            }

            if trimmed.hasPrefix("- ") {
                flushParagraph()
                result.append(.bullet(text: String(trimmed.dropFirst(2))))
                continue
            }

            currentParagraph.append(line)
        }

        if inCodeBlock {
            result.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
        }

        flushParagraph()

        if result.last == .spacer {
            _ = result.popLast()
        }

        return result
    }
}

private extension View {
    @ViewBuilder
    func `if`<Modified: View>(_ condition: Bool, transform: (Self) -> Modified) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
