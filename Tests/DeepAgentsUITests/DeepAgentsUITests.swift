import XCTest
@testable import DeepAgentsUI
import SwiftyJSON

final class DeepAgentsUITests: XCTestCase {

    // MARK: - Type Tests

    func testToolCallStatusRawValues() {
        XCTAssertEqual(ToolCallStatus.pending.rawValue, "pending")
        XCTAssertEqual(ToolCallStatus.completed.rawValue, "completed")
        XCTAssertEqual(ToolCallStatus.error.rawValue, "error")
        XCTAssertEqual(ToolCallStatus.interrupted.rawValue, "interrupted")
    }

    func testTodoStatusRawValues() {
        XCTAssertEqual(TodoStatus.pending.rawValue, "pending")
        XCTAssertEqual(TodoStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(TodoStatus.completed.rawValue, "completed")
    }

    func testMessageTypeRawValues() {
        XCTAssertEqual(MessageType.human.rawValue, "human")
        XCTAssertEqual(MessageType.ai.rawValue, "ai")
        XCTAssertEqual(MessageType.tool.rawValue, "tool")
        XCTAssertEqual(MessageType.system.rawValue, "system")
    }

    func testMessageContentString() {
        // String content
        let stringMessage = Message(id: "1", type: .human, content: JSON("Hello"))
        XCTAssertEqual(stringMessage.contentString, "Hello")

        // Array content with text block
        let arrayContent: JSON = [
            ["type": "text", "text": "World"]
        ]
        let arrayMessage = Message(id: "2", type: .ai, content: arrayContent)
        XCTAssertEqual(arrayMessage.contentString, "World")
    }

    func testToolCallFromJSON() {
        let json: JSON = [
            "id": "tc1",
            "name": "search",
            "args": ["query": "test"],
            "status": "completed",
            "result": "Found results"
        ]

        let toolCall = ToolCall(json: json)
        XCTAssertEqual(toolCall.id, "tc1")
        XCTAssertEqual(toolCall.name, "search")
        XCTAssertEqual(toolCall.status, .completed)
        XCTAssertEqual(toolCall.result, "Found results")
    }

    func testTodoItemFromJSON() {
        let json: JSON = [
            "id": "todo1",
            "content": "Write tests",
            "status": "in_progress"
        ]

        let todo = TodoItem(json: json)
        XCTAssertEqual(todo.id, "todo1")
        XCTAssertEqual(todo.content, "Write tests")
        XCTAssertEqual(todo.status, .inProgress)
    }

    // MARK: - Utils Tests

    func testIsValidUUID() {
        XCTAssertTrue(isValidUUID("550e8400-e29b-41d4-a716-446655440000"))
        XCTAssertTrue(isValidUUID("550E8400-E29B-41D4-A716-446655440000"))
        XCTAssertFalse(isValidUUID("not-a-uuid"))
        XCTAssertFalse(isValidUUID("550e8400-e29b-41d4-a716"))
    }

    func testGetFileExtension() {
        XCTAssertEqual(getFileExtension("/path/to/file.swift"), "swift")
        XCTAssertEqual(getFileExtension("file.JS"), "js")
        XCTAssertEqual(getFileExtension("noextension"), "")
    }

    func testGetLanguageFromExtension() {
        XCTAssertEqual(getLanguageFromExtension("swift"), "swift")
        XCTAssertEqual(getLanguageFromExtension("ts"), "typescript")
        XCTAssertEqual(getLanguageFromExtension("py"), "python")
        XCTAssertEqual(getLanguageFromExtension("unknown"), "plaintext")
    }

    func testExtractStringFromMessageContent() {
        let stringMessage = Message(id: "1", type: .human, content: JSON("Hello World"))
        XCTAssertEqual(extractStringFromMessageContent(stringMessage), "Hello World")

        let arrayMessage = Message(id: "2", type: .ai, content: JSON([
            ["type": "text", "text": "Part 1"],
            ["type": "text", "text": "Part 2"]
        ]))
        XCTAssertEqual(extractStringFromMessageContent(arrayMessage), "Part 1Part 2")
    }

    func testIsPreparingToCallTaskTool() {
        let messagesWithoutTask: [Message] = [
            Message(id: "1", type: .human, content: JSON("Hello")),
            Message(id: "2", type: .ai, content: JSON("Hi there"))
        ]
        XCTAssertFalse(isPreparingToCallTaskTool(messagesWithoutTask))

        let messagesWithTask: [Message] = [
            Message(id: "1", type: .human, content: JSON("Hello")),
            Message(id: "2", type: .ai, content: JSON(""), toolCalls: [JSON(["name": "task"])])
        ]
        XCTAssertTrue(isPreparingToCallTaskTool(messagesWithTask))
    }
}
