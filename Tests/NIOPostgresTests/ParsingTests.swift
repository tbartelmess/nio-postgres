//
//  NIOPostgresParsingTests.swift
//  NIOPostgresTests
//
//  Created by Thomas Bartelmess on 2019-03-10.
//

import NIOPostgres
import XCTest

class ParsingTests: XCTestCase {

    var fixtureDirectory: URL {
        let currentFile = URL(fileURLWithPath: #file)
        let fixtureDirectory = currentFile.deletingLastPathComponent()
                                          .appendingPathComponent("Fixtures")
        return fixtureDirectory;
    }

    func getFixture(named name: String) -> ByteBuffer {
        let fixturePath = fixtureDirectory.appendingPathComponent("\(name).fixture")
        if !FileManager.default.fileExists(atPath: fixturePath.path) {
            XCTFail("Fixture named: \(name), not found at \(fixturePath.path))")

        }
        let data = try! Data(contentsOf: fixturePath)
        var byteBuffer = ByteBufferAllocator().buffer(capacity: data.count)
        byteBuffer.writeBytes(data)

        return byteBuffer
    }

    /// Parses a message from a fixture, returning the parsed PostgreSQL message
    ///
    /// - parameters:
    ///     - fixtureName: name of the fixture in the fixtures directory (without the file extension)
    ///     - hasType: Specifies if the message has the message type prefix (1 character)
    /// - returns: The Message struct, if parsing failed this, `XCTFail` with the error description will be called
    func parseMessage<T: PostgresMessageType>(fixtureName: String, hasType: Bool = true) -> T? {
        do {
            var fixture = getFixture(named: fixtureName)
            if (hasType) {
                let _: UInt8 = fixture.readInteger()!
            }
            let _: UInt32 = fixture.readInteger()!
            return try T.parse(from: &fixture)
        } catch PostgresError.protocol(let errorMessage) {
            XCTFail("Failed to parse message: \(errorMessage)")
        } catch {
            XCTFail("Unexpected error")
        }
        fatalError()
    }

    func testParseStartupMessage() {
        let startupMessage: PostgresMessage.Startup? = parseMessage(fixtureName: "startup", hasType: false)
        XCTAssertEqual(startupMessage?.protocolVersion, 196608)
        let parameters = startupMessage?.parameters
        XCTAssertEqual(parameters?["user"], "thomasbartelmess")
        XCTAssertEqual(parameters?["database"], "thomasbartelmess")
    }

    
}
