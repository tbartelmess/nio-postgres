import NIO

extension PostgresMessage {
    /// Identifies the message type. ReadyForQuery is sent whenever the backend is ready for a new query cycle.
    public struct ReadyForQuery: PostgresMessageType, CustomStringConvertible {

        public enum TransactionStatus: UInt8 {
            case idle  = 0x49 // 'I' character
            case inTransaction = 0x54 // 'T' character
            case inFailedTransaction = 0x46 // 'F' character
        }

        /// Parses an instance of this message type from a byte buffer.
        public static func parse(from buffer: inout ByteBuffer) throws -> ReadyForQuery {
            guard let statusCode = buffer.readInteger(as: UInt8.self) else {
                throw PostgresError.protocol("Could not read transaction status from ready for query message")
            }
            guard let status = TransactionStatus(rawValue: statusCode) else {
                throw PostgresError.protocol("Invalid status code \(statusCode).")
            }
            return .init(transactionStatus: status)
        }

        public init(transactionStatus: TransactionStatus) {
            self.transactionStatus = transactionStatus
        }



        /// Current backend transaction status indicator.
        /// Possible values are 'I' if idle (not in a transaction block);
        /// 'T' if in a transaction block; or 'E' if in a failed transaction block
        /// (queries will be rejected until block is ended).
        public var transactionStatus: TransactionStatus
        
        /// See `CustomStringConvertible`.
        public var description: String {
            let char = String(bytes: [transactionStatus.rawValue], encoding: .ascii) ?? "n/a"
            return "transactionStatus: \(char)"
        }

        public static var identifier: PostgresMessage.Identifier {
            return .readyForQuery
        }

        public func serialize(into buffer: inout ByteBuffer) throws {
            buffer.writeInteger(transactionStatus.rawValue)
        }
    }
}
