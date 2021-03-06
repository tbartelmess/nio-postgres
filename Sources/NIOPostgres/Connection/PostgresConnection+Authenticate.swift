import CMD5
import NIO

extension PostgresConnection {
    public func authenticate(username: String, database: String? = nil, password: String? = nil) -> EventLoopFuture<Void> {
        let auth = PostgresAuthenticationRequest(
            username: username,
            database: database,
            password: password
        )
        return self.send(auth)
    }
}

// MARK: Private

private final class PostgresAuthenticationRequest: PostgresRequestHandler {
    enum State {
        case ready
        case done
    }
    
    let username: String
    let database: String?
    let password: String?
    var state: State

    var errorMessageIsFinal: Bool {
        return true
    }

    init(username: String, database: String?, password: String?) {
        self.state = .ready
        self.username = username
        self.database = database
        self.password = password
    }
    
    func respond(to message: PostgresMessage) throws -> [PostgresMessage]? {
        switch self.state {
        case .ready:
            switch message.identifier {
            case .authentication:
                let auth = try PostgresMessage.Authentication(message: message)
                switch auth {
                case .md5(let salt):
                    let pwdhash = self.md5((self.password ?? "") + self.username).hexdigest()
                    let hash = "md5" + self.md5(self.bytes(pwdhash) + salt).hexdigest()
                    return try [PostgresMessage.Password(string: hash).message()]
                case .plaintext:
                    return try [PostgresMessage.Password(string: self.password ?? "").message()]
                case .ok:
                    self.state = .done
                    return []
                }
            default: throw PostgresError.protocol("Unexpected response to start message: \(message)")
            }
        case .done:
            switch message.identifier {
            case .parameterStatus:
                // self.status[status.parameter] = status.value
                return []
            case .backendKeyData:
                // self.processID = data.processID
                // self.secretKey = data.secretKey
                return []
            case .readyForQuery:
                return nil
            default: throw PostgresError.protocol("Unexpected response to password authentication: \(message)")
            }
        }
        
    }
    
    func start() throws -> [PostgresMessage] {
        return try [
            PostgresMessage.Startup.versionThree(parameters: [
                "user": self.username,
                "database": self.database ?? username
            ]).message()
        ]
    }
    
    // MARK: Private
    
    private func md5(_ string: String) -> [UInt8] {
        return md5(self.bytes(string))
    }
    
    private func md5(_ message: [UInt8]) -> [UInt8] {
        var message = message
        var ctx = MD5_CTX()
        MD5_Init(&ctx)
        MD5_Update(&ctx, &message, numericCast(message.count))
        var digest = [UInt8](repeating: 0, count: 16)
        MD5_Final(&digest, &ctx)
        return digest
    }
    
    func bytes(_ string: String) -> [UInt8] {
        return string.withCString { ptr in
            return UnsafeBufferPointer(start: ptr, count: string.count).withMemoryRebound(to: UInt8.self) { buffer in
                return [UInt8](buffer)
            }
        }
    }
}
