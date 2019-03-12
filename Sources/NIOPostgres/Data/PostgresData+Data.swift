import Foundation

extension PostgresData {
    public var data: Data? {
        guard var value = self.value else {
            return nil
        }
        switch self.formatCode {
        case .binary:
            return value.readData(length: value.readableBytes)
        case .text:
            fatalError("Decoding the hex representation is not supported")
        }
    }


    public var bytes: [UInt8]? {
        guard var value = self.value else {
            return nil
        }
        switch self.formatCode {
        case .binary:
            return value.readBytes(length: value.readableBytes)
        case .text:
            fatalError("Decoding the hex representation is not supported")
        }
    }
}
