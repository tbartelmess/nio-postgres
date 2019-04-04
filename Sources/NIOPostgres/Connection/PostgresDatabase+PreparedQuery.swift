import Foundation

extension PostgresDatabase {

    public func prepare(query: String) -> EventLoopFuture<PreparedQuery> {
        let name = "nio-postgres-\(UUID().uuidString)"
        let prepare = PrepareQueryHandler(query, as: name)
        return self.send(prepare).map { () -> (PreparedQuery) in
            let prepared = PreparedQuery(database: self, name: name, rowDescription: prepare.rowLookupTable!)
            return prepared
        }
    }
}


public class PreparedQuery {
    let database: PostgresDatabase
    let name: String
    let rowLookupTable: PostgresRow.LookupTable

    init(database: PostgresDatabase, name: String, rowDescription: PostgresRow.LookupTable) {
        self.database = database
        self.name = name
        self.rowLookupTable = rowDescription
    }

    public func execute(_ binds: [PostgresData] = []) -> EventLoopFuture<[PostgresRow]> {
        var rows: [PostgresRow] = []
        return execute(binds) { rows.append($0) }.map { rows }

    }

    public func execute(_ binds: [PostgresData] = [], _ onRow: @escaping (PostgresRow) throws -> ()) -> EventLoopFuture<Void> {
        let handler = ExecutePreparedQueryHandler(query: self, binds: binds, onRow: onRow)
        return database.send(handler)
    }
}


private final class PrepareQueryHandler: PostgresRequestHandler {
    let query: String
    let name: String
    var rowLookupTable: PostgresRow.LookupTable?
    var resultFormatCodes: [PostgresFormatCode]

    init(_ query: String, as name: String) {
        self.query = query
        self.name = name
        self.resultFormatCodes = [.binary]
    }

    func respond(to message: PostgresMessage) throws -> [PostgresMessage]? {
        switch message.identifier {
        case .rowDescription:
            let row = try PostgresMessage.RowDescription(message: message)
            self.rowLookupTable = PostgresRow.LookupTable(
                rowDescription: row,
                resultFormat: self.resultFormatCodes
            )
            return []
        case .parseComplete, .parameterDescription:
            return []
        case .readyForQuery:
            return nil
        default:
            fatalError("Unexpected message: \(message)")
        }

    }

    func start() throws -> [PostgresMessage] {
        let parse = PostgresMessage.Parse(
            statementName: self.name,
            query: self.query,
            parameterTypes: []
        )
        let describe = PostgresMessage.Describe(
            command: .statement,
            name: self.name
        )
        return try [parse.message(), describe.message(), PostgresMessage.Sync().message()]
    }

}


private final class ExecutePreparedQueryHandler: PostgresRequestHandler {

    let query: PreparedQuery
    let binds: [PostgresData]
    var onRow: (PostgresRow) throws -> ()
    var resultFormatCodes: [PostgresFormatCode]

    init(query: PreparedQuery, binds: [PostgresData], onRow: @escaping (PostgresRow) throws -> ()) {
        self.query = query
        self.binds = binds
        self.onRow = onRow
        self.resultFormatCodes = [.binary]

    }

    func respond(to message: PostgresMessage) throws -> [PostgresMessage]? {
        switch message.identifier {
        case .bindComplete:
            return []
        case .dataRow:
            let data = try PostgresMessage.DataRow(message: message)
            let row = PostgresRow(dataRow: data, lookupTable: query.rowLookupTable)
            try onRow(row)
            return []
        case .noData:
            return []
        case .commandComplete:
            return []
        case .readyForQuery:
            return nil
        default: throw PostgresError.protocol("Unexpected message during query: \(message)")
        }
    }

    func start() throws -> [PostgresMessage] {

        let bind = PostgresMessage.Bind(
            portalName: "",
            statementName: query.name,
            parameterFormatCodes: self.binds.map { $0.formatCode },
            parameters: self.binds.map { .init(value: $0.value) },
            resultFormatCodes: self.resultFormatCodes
        )
        let execute = PostgresMessage.Execute(
            portalName: "",
            maxRows: 0
        )

        let sync = PostgresMessage.Sync()
        return try [bind.message(), execute.message(), sync.message()]
    }


}
