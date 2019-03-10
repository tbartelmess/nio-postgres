import NIO

/// Extension to Int32 to extract minor/major version
/// from the protocol version
fileprivate extension Int32 {
    var majorVersion: Int16 {
        return Int16(self >> 16)
    }

    var minorVersion: Int16 {
        return Int16(self & 0xFFFF)
    }
}

extension PostgresMessage {
    /// First message sent from the frontend during startup.
    public struct Startup: PostgresMessageType {
        public static func parse(from buffer: inout ByteBuffer) throws -> PostgresMessage.Startup {
            guard let protocolVersion = buffer.readInteger(as: Int32.self) else {
                throw PostgresError.protocol("Failed to read protocol version")
            }

            var keyValues : [String: String] = [:]

            var currentKey: String?
            while true {
                guard let value = buffer.readNullTerminatedString() else {
                    break
                }
                if value.lengthOfBytes(using: .ascii) == 0 {
                    break
                }
                if let key = currentKey {
                    keyValues[key] = value
                    currentKey = nil
                } else {
                    currentKey = value
                }
            }
            return Startup(protocolVersion: protocolVersion, parameters: keyValues)
        }
        
        public static var identifier: PostgresMessage.Identifier {
            return .none
        }
        
        public var description: String {
            return "Startup()"
        }
        
        /// Creates a `Startup` with "3.0" as the protocol version.
        public static func versionThree(parameters: [String: String]) -> Startup {
            return .init(protocolVersion: 0x00_03_00_00, parameters: parameters)
        }
        
        /// The protocol version number. The most significant 16 bits are the major
        /// version number (3 for the protocol described here). The least significant
        /// 16 bits are the minor version number (0 for the protocol described here).
        public var protocolVersion: Int32

        /// Returns the major protocol version of the protocol (upper 16 bits)
        public var majorProtocolVersion: Int16 {
            return protocolVersion.majorVersion
        }

        /// Returns the minor protocol version of the protocol (lower 16 bits)
        public var minorProtocolVersion: Int16 {
            return protocolVersion.minorVersion
        }

        /// The protocol version number is followed by one or more pairs of parameter
        /// name and value strings. A zero byte is required as a terminator after
        /// the last name/value pair. Parameters can appear in any order. user is required,
        /// others are optional. Each parameter is specified as:
        public var parameters: [String: String]
        
        /// Creates a new `PostgreSQLStartupMessage`.
        public init(protocolVersion: Int32, parameters: [String: String]) {
            self.protocolVersion = protocolVersion
            self.parameters = parameters
        }
        
        /// Serializes this message into a byte buffer.
        public func serialize(into buffer: inout ByteBuffer) {
            buffer.writeInteger(self.protocolVersion)
            for (key, val) in parameters {
                buffer.writeString(key + "\0")
                buffer.writeString(val + "\0")
            }
            // terminator
            buffer.writeString("\0")
        }
    }
}
