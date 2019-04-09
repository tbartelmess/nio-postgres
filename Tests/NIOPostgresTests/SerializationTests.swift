import Foundation
import XCTest
import NIO
import NIOPostgres


class SerializationTests: XCTestCase {
    func testErrorSerialization() throws {
        let testFields: [PostgresMessage.Error.Field: String] =
            [.severity: "ERROR",
            .sqlState: "42P01",
            .message: "relation \"foo\" does not exist"]
        let message = PostgresMessage.Error(fields: testFields)
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        try message.serialize(into: &buffer)
        let parsed = try PostgresMessage.Error.parse(from: &buffer)
        XCTAssertEqual(parsed.fields[.severity], "ERROR")
        XCTAssertEqual(parsed.fields[.sqlState], "42P01")
        XCTAssertEqual(parsed.fields[.message], "relation \"foo\" does not exist")
    }
}
