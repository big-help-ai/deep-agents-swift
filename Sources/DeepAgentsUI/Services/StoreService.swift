import Foundation
import SwiftyJSON

// MARK: - Store Service

@Observable
@MainActor
public final class StoreService {
    // MARK: - Properties

    public private(set) var namespaces: [[String]] = []
    public private(set) var items: [StoreItem] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: Error?

    public var currentNamespace: [String] = []

    private var client: LangGraphClient?

    // MARK: - Initialization

    public init() {}

    // MARK: - Configuration

    public func configure(deploymentUrl: String, apiKey: String?) {
        self.client = LangGraphClient(apiUrl: deploymentUrl, apiKey: apiKey)
    }

    // MARK: - Namespace Operations

    public func loadNamespaces(prefix: [String]? = nil) async {
        guard let client = client else { return }

        isLoading = true
        error = nil

        do {
            namespaces = try await client.store.listNamespaces(
                prefix: prefix,
                limit: 100
            )
        } catch {
            self.error = error
        }

        isLoading = false
    }

    public func loadItems(namespace: [String]) async {
        guard let client = client else { return }

        isLoading = true
        error = nil
        currentNamespace = namespace

        do {
            items = try await client.store.searchItems(
                namespacePrefix: namespace,
                limit: 100
            )
        } catch {
            self.error = error
        }

        isLoading = false
    }

    public func refresh() async {
        await loadNamespaces(prefix: currentNamespace.isEmpty ? nil : currentNamespace)
        if !currentNamespace.isEmpty {
            await loadItems(namespace: currentNamespace)
        }
    }

    // MARK: - Navigation

    public func navigateToNamespace(_ namespace: [String]) async {
        currentNamespace = namespace
        await loadNamespaces(prefix: namespace)
        await loadItems(namespace: namespace)
    }

    public func navigateUp() async {
        guard !currentNamespace.isEmpty else { return }
        currentNamespace.removeLast()
        await loadNamespaces(prefix: currentNamespace.isEmpty ? nil : currentNamespace)
        if !currentNamespace.isEmpty {
            await loadItems(namespace: currentNamespace)
        } else {
            items = []
        }
    }

    public func navigateToRoot() async {
        currentNamespace = []
        items = []
        await loadNamespaces()
    }

    // MARK: - Helpers

    /// Get child namespaces (direct children of current namespace)
    public var childNamespaces: [[String]] {
        let depth = currentNamespace.count + 1
        return namespaces
            .filter { $0.count == depth && $0.starts(with: currentNamespace) }
    }

    /// Get the display name for a namespace (last component)
    public func displayName(for namespace: [String]) -> String {
        namespace.last ?? "/"
    }
}
