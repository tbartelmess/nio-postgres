import NIO

extension PostgresMessage {
    /// Identifies the message as a simple query.
    public struct SimpleQuery: PostgresMessageType {
        public static func parse(from buffer: inout ByteBuffer) throws -> PostgresMessage.SimpleQuery {
            guard let query = buffer.readNullTerminatedString() else {
                throw PostgresError.protocol("Failed to read query string")
            }
            return .init(string: query)
        }
        
        public static var identifier: PostgresMessage.Identifier {
            return .query
        }
        
        public var description: String {
            return "SimpleQuery(\(self.string))"
        }
        
        /// The query string itself.
        public var string: String
        
        /// Serializes this message into a byte buffer.
        public func serialize(into buffer: inout ByteBuffer) {
            buffer.writeString(self.string + "\0")
        }
    }
}
