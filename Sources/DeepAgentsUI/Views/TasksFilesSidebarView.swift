import SwiftUI

// MARK: - Tasks Files Sidebar View

public struct TasksFilesSidebarView: View {
    let files: [String: String]
    let setFiles: ([String: String]) -> Void
    let editDisabled: Bool

    @State private var selectedFile: FileItem?

    public init(
        files: [String: String],
        setFiles: @escaping ([String: String]) -> Void,
        editDisabled: Bool = false
    ) {
        self.files = files
        self.setFiles = setFiles
        self.editDisabled = editDisabled
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if files.isEmpty {
                Text("No files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                    ForEach(sortedFiles, id: \.path) { file in
                        fileCard(file)
                    }
                }
            }
        }
        .sheet(item: $selectedFile) { file in
            FileViewDialogView(
                file: file,
                onSaveFile: { updatedFile in
                    saveFile(updatedFile, originalPath: file.path)
                },
                onClose: {
                    selectedFile = nil
                },
                editDisabled: editDisabled
            )
        }
    }

    private var sortedFiles: [FileItem] {
        files.map { FileItem(path: $0.key, content: $0.value) }
            .sorted { $0.path < $1.path }
    }

    private func fileCard(_ file: FileItem) -> some View {
        Button {
            selectedFile = file
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // File icon
                Image(systemName: iconForFile(file.path))
                    .font(.title2)
                    .foregroundStyle(.blue)

                // File name
                Text(URL(fileURLWithPath: file.path).lastPathComponent)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // File size indicator
                Text("\(file.content.count) chars")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func iconForFile(_ path: String) -> String {
        let ext = getFileExtension(path)

        switch ext {
        case "swift", "js", "ts", "jsx", "tsx", "py", "rb", "go", "rs", "java", "kt", "c", "cpp", "h", "cs":
            return "doc.text.fill"
        case "json", "yaml", "yml", "xml":
            return "curlybraces"
        case "md", "markdown", "txt":
            return "doc.plaintext"
        case "html", "css", "scss":
            return "globe"
        case "png", "jpg", "jpeg", "gif", "svg":
            return "photo"
        case "pdf":
            return "doc.richtext"
        default:
            return "doc"
        }
    }

    private func saveFile(_ updatedFile: FileItem, originalPath: String) {
        var newFiles = files

        // Remove old file if path changed
        if updatedFile.path != originalPath {
            newFiles.removeValue(forKey: originalPath)
        }

        // Add/update file
        newFiles[updatedFile.path] = updatedFile.content

        setFiles(newFiles)
    }
}

// MARK: - Files Popover

public struct FilesPopover: View {
    let files: [String: String]
    let setFiles: ([String: String]) -> Void
    let editDisabled: Bool

    public init(
        files: [String: String],
        setFiles: @escaping ([String: String]) -> Void,
        editDisabled: Bool = false
    ) {
        self.files = files
        self.setFiles = setFiles
        self.editDisabled = editDisabled
    }

    public var body: some View {
        TasksFilesSidebarView(
            files: files,
            setFiles: setFiles,
            editDisabled: editDisabled
        )
    }
}
