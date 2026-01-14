import SwiftUI
import Markdown

// MARK: - Markdown Content View

public struct MarkdownContentView: View {
    let content: String

    public init(content: String) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let document = Document(parsing: content)
            ForEach(Array(document.children.enumerated()), id: \.offset) { _, markup in
                MarkupView(markup: markup)
            }
        }
    }
}

// MARK: - Markup View

private struct MarkupView: View {
    let markup: any Markup

    var body: some View {
        switch markup {
        case let paragraph as Paragraph:
            ParagraphView(paragraph: paragraph)

        case let heading as Heading:
            HeadingView(heading: heading)

        case let codeBlock as CodeBlock:
            CodeBlockView(codeBlock: codeBlock)

        case let list as UnorderedList:
            UnorderedListView(list: list)

        case let list as OrderedList:
            OrderedListView(list: list)

        case let blockquote as BlockQuote:
            BlockQuoteView(blockquote: blockquote)

        case let thematicBreak as ThematicBreak:
            ThematicBreakView(thematicBreak: thematicBreak)

        default:
            // Fallback: render as plain text
            Text(markup.format())
        }
    }
}

// MARK: - Paragraph View

private struct ParagraphView: View {
    let paragraph: Paragraph

    var body: some View {
        InlineContentView(children: Array(paragraph.children))
    }
}

// MARK: - Heading View

private struct HeadingView: View {
    let heading: Heading

    var body: some View {
        InlineContentView(children: Array(heading.children))
            .font(fontForLevel(heading.level))
            .fontWeight(.bold)
            .padding(.vertical, 4)
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        case 3: return .title3
        case 4: return .headline
        default: return .subheadline
        }
    }
}

// MARK: - Code Block View

private struct CodeBlockView: View {
    let codeBlock: CodeBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language = codeBlock.language, !language.isEmpty {
                Text(language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeBlock.code)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
            }
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Unordered List View

private struct UnorderedListView: View {
    let list: UnorderedList

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.children.enumerated()), id: \.offset) { _, item in
                if let listItem = item as? ListItem {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(listItem.children.enumerated()), id: \.offset) { _, child in
                                MarkupView(markup: child)
                            }
                        }
                    }
                }
            }
        }
        .padding(.leading, 8)
    }
}

// MARK: - Ordered List View

private struct OrderedListView: View {
    let list: OrderedList

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(list.children.enumerated()), id: \.offset) { index, item in
                if let listItem = item as? ListItem {
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .frame(minWidth: 20, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(listItem.children.enumerated()), id: \.offset) { _, child in
                                MarkupView(markup: child)
                            }
                        }
                    }
                }
            }
        }
        .padding(.leading, 8)
    }
}

// MARK: - Block Quote View

private struct BlockQuoteView: View {
    let blockquote: BlockQuote

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(blockquote.children.enumerated()), id: \.offset) { _, child in
                    MarkupView(markup: child)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Thematic Break View

private struct ThematicBreakView: View {
    let thematicBreak: ThematicBreak

    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

// MARK: - Inline Content View

private struct InlineContentView: View {
    let children: [any Markup]

    var body: some View {
        children.reduce(Text("")) { result, child in
            result + renderInlineMarkup(child)
        }
    }

    private func renderInlineMarkup(_ markup: any Markup) -> Text {
        switch markup {
        case let text as Markdown.Text:
            return Text(text.string)

        case let strong as Strong:
            return renderInlineChildren(Array(strong.children)).bold()

        case let emphasis as Emphasis:
            return renderInlineChildren(Array(emphasis.children)).italic()

        case let code as InlineCode:
            return Text(code.code)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.purple)

        case let link as Markdown.Link:
            let text = renderInlineChildren(Array(link.children))
            // Note: SwiftUI Text doesn't support tappable links inline
            // We just color them blue
            return text.foregroundColor(.blue)

        case let softBreak as SoftBreak:
            return Text(" ")

        case let lineBreak as LineBreak:
            return Text("\n")

        default:
            return Text(markup.format())
        }
    }

    private func renderInlineChildren(_ children: [any Markup]) -> Text {
        children.reduce(Text("")) { result, child in
            result + renderInlineMarkup(child)
        }
    }
}
