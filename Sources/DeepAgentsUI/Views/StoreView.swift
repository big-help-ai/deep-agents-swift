import SwiftUI
import SwiftyJSON

// MARK: - Store View

public struct StoreView: View {
    @Environment(StoreService.self) private var storeService

    @State private var selectedItem: StoreItem?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Breadcrumb navigation
                breadcrumbView

                Divider()

                // Content
                if storeService.isLoading && storeService.namespaces.isEmpty {
                    loadingView
                } else if storeService.error != nil {
                    errorView
                } else {
                    contentView
                }
            }
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await storeService.loadNamespaces()
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
        }
    }

    // MARK: - Breadcrumb View

    private var breadcrumbView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    Task {
                        await storeService.navigateToRoot()
                    }
                } label: {
                    Image(systemName: "house")
                        .foregroundStyle(storeService.currentNamespace.isEmpty ? Color.primary : Color.blue)
                }
                .disabled(storeService.currentNamespace.isEmpty)

                ForEach(Array(storeService.currentNamespace.enumerated()), id: \.offset) { index, component in
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                let targetNamespace = Array(storeService.currentNamespace.prefix(index + 1))
                                await storeService.navigateToNamespace(targetNamespace)
                            }
                        } label: {
                            Text(component)
                                .foregroundStyle(index == storeService.currentNamespace.count - 1 ? Color.primary : Color.blue)
                        }
                        .disabled(index == storeService.currentNamespace.count - 1)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Content View

    private var contentView: some View {
        List {
            // Child namespaces (folders)
            if !storeService.childNamespaces.isEmpty {
                Section("Namespaces") {
                    ForEach(storeService.childNamespaces, id: \.self) { namespace in
                        Button {
                            Task {
                                await storeService.navigateToNamespace(namespace)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.blue)
                                Text(storeService.displayName(for: namespace))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Items (files)
            if !storeService.items.isEmpty {
                Section("Items") {
                    ForEach(storeService.items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.key)
                                        .font(.subheadline)
                                    if let updatedAt = item.updatedAt {
                                        Text(formatDate(updatedAt))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Empty state
            if storeService.childNamespaces.isEmpty && storeService.items.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No items")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await storeService.refresh()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Failed to load store")
                .font(.headline)
            if let error = storeService.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button("Retry") {
                Task {
                    await storeService.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Item Detail View

struct ItemDetailView: View {
    let item: StoreItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        metadataRow("Key", value: item.key)
                        metadataRow("Namespace", value: item.namespace.joined(separator: " / "))
                        if let createdAt = item.createdAt {
                            metadataRow("Created", value: formatFullDate(createdAt))
                        }
                        if let updatedAt = item.updatedAt {
                            metadataRow("Updated", value: formatFullDate(updatedAt))
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)

                    // Value
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Value")
                            .font(.headline)

                        Text(prettyPrintJSON(item.value))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle(item.key)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func prettyPrintJSON(_ json: JSON) -> String {
        if let data = try? json.rawData(options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return json.description
    }
}
