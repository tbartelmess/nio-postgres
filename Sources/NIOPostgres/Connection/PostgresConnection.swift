import NIO

public final class PostgresConnection {
    let handler: InboundHandler
    
    #warning("publicize these values?")
    public var status: [String: String]
    var processID: Int32?
    var secretKey: Int32?
    
    var tableNames: TableNames?
    
    public var eventLoop: EventLoop {
        return self.handler.channel.eventLoop
    }
    
    public var closeFuture: EventLoopFuture<Void> {
        return handler.channel.closeFuture
    }
    
    init(_ handler: InboundHandler) {
        self.handler = handler
        self.status = [:]
    }
    
    public func close() -> EventLoopFuture<Void> {
        return handler.channel.close(mode: .all)
    }
}