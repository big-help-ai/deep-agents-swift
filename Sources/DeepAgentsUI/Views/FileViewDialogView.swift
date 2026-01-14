import SwiftUI

// MARK: - File View Dialog View

public struct FileViewDialogView: View {
    let file: FileItem?
    let onSaveFile: (FileItem) async -> Void
    let onClose: () -> Void
    let editDisabled: Bool

    @State private var isEditing = false
    @State private var editedFileName: String = ""
    @State private var editedContent: String = ""
    @State private var isSaving = false

    public init(
        file: FileItem?,
        onSaveFile: @escaping (FileItem) async -> Void,
        onClose: @escaping () -> Void,
        editDisabled: Bool = false
    ) {
        self.file = file
        self.onSaveFile = onSaveFile
        self.onClose = onClose
        self.editDisabled = editDisabled
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let file = file {
                    fileContent(file)
                } else {
                    Text("No file selected")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isEditing ? "Edit File" : (file?.path ?? "File"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Close") {
                        if isEditing {
                            isEditing = false
                            resetEditState()
                        } else {
                            onClose()
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            saveFile()
                        }
                        .disabled(isSaving || !isValidFileName)
                    } else if !editDisabled {
                        Menu {
                            Button {
                                startEditing()
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button {
                                copyToClipboard()
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }

                            Button {
                                downloadFile()
                            } label: {
                                Label("Download", systemImage: "arrow.down.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fileContent(_ file: FileItem) -> some View {
        let ext = getFileExtension(file.path)

        if isEditing {
            editingView
        } else if ext == "md" || ext == "markdown" {
            // Render markdown
            ScrollView {
                MarkdownContentView(content: file.content)
                    .padding()
            }
        } else {
            // Code view
            codeView(file.content, language: getLanguageFromExtension(ext))
        }
    }

    private var editingView: some View {
        VStack(spacing: 0) {
            // File name field
            HStack {
                Text("File name:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("filename", text: $editedFileName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding()

            Divider()

            // Content editor
            TextEditor(text: $editedContent)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemBackground))
        }
    }

    private func codeView(_ content: String, language: String) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Language label
                HStack {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)

                // Code content with line numbers
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(1...max(content.components(separatedBy: "\n").count, 1), id: \.self) { lineNum in
                            Text("\(lineNum)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(minWidth: 30, alignment: .trailing)
                        }
                    }
                    .padding(.trailing, 8)
                    .padding(.leading, 8)

                    Divider()

                    // Code
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .padding(.leading, 8)
                        .textSelection(.enabled)
                }
                .padding(.vertical)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Helpers

    private var isValidFileName: Bool {
        let trimmed = editedFileName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty &&
               !trimmed.contains("/") &&
               !trimmed.contains(" ")
    }

    private func startEditing() {
        guard let file = file else { return }
        editedFileName = URL(fileURLWithPath: file.path).lastPathComponent
        editedContent = file.content
        isEditing = true
    }

    private func resetEditState() {
        editedFileName = ""
        editedContent = ""
    }

    private func saveFile() {
        guard let file = file else { return }

        isSaving = true

        // Construct new path
        let directory = URL(fileURLWithPath: file.path).deletingLastPathComponent().path
        let newPath = directory.isEmpty || directory == "." ? editedFileName : "\(directory)/\(editedFileName)"

        let updatedFile = FileItem(path: newPath, content: editedContent)

        Task {
            await onSaveFile(updatedFile)
            isSaving = false
            isEditing = false
            resetEditState()
        }
    }

    private func copyToClipboard() {
        guard let file = file else { return }
        UIPasteboard.general.string = file.content
    }

    private func downloadFile() {
        // In iOS, we would typically use UIActivityViewController
        // For now, just copy to clipboard as a fallback
        copyToClipboard()
    }
}
