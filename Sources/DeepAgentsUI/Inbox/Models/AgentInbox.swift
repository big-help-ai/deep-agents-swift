import Foundation
import SwiftyJSON

/// Configuration for an agent inbox.
public struct AgentInbox: Identifiable, Codable, Equatable, Sendable {
    /// A unique identifier for the inbox
    public var id: String
    /// The ID of the graph
    public var graphId: String
    /// The URL of the deployment. Either a localhost URL, or a deployment URL
    public var deploymentUrl: String
    /// Optional name for the inbox, used in the UI to label the inbox
    public var name: String?
    /// Whether or not the inbox is selected
    public var selected: Bool
    /// The tenant ID for the deployment (only for deployed graphs)
    public var tenantId: String?
    /// Creation timestamp
    public var createdAt: String

    public init(
        id: String = UUID().uuidString,
        graphId: String,
        deploymentUrl: String,
        name: String? = nil,
        selected: Bool = false,
        tenantId: String? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) {
        self.id = id
        self.graphId = graphId
        self.deploymentUrl = deploymentUrl
        self.name = name
        self.selected = selected
        self.tenantId = tenantId
        self.createdAt = createdAt
    }

    public init(json: JSON) {
        self.id = json["id"].stringValue
        self.graphId = json["graphId"].stringValue
        self.deploymentUrl = json["deploymentUrl"].stringValue
        self.name = json["name"].string
        self.selected = json["selected"].boolValue
        self.tenantId = json["tenantId"].string
        self.createdAt = json["createdAt"].stringValue
    }

    public func toJSON() -> JSON {
        var dict: [String: Any] = [
            "id": id,
            "graphId": graphId,
            "deploymentUrl": deploymentUrl,
            "selected": selected,
            "createdAt": createdAt
        ]
        if let name = name {
            dict["name"] = name
        }
        if let tenantId = tenantId {
            dict["tenantId"] = tenantId
        }
        return JSON(dict)
    }

    /// Display name (uses custom name or graph ID)
    public var displayName: String {
        name ?? graphId
    }
}
