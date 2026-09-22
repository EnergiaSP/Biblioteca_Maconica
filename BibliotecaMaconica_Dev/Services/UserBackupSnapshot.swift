import Foundation

struct UserBackupSnapshot: Codable, Equatable, Sendable {
    struct Record: Codable, Equatable, Sendable {
        let key: String
        let member: String?
        let value: Data?
        let timestamp: Double
        let revision: String

        func newer(than other: Record) -> Bool {
            timestamp != other.timestamp ? timestamp > other.timestamp : revision > other.revision
        }
    }
    private(set) var records: [String: Record] = [:]

    static func isSet(_ key: String) -> Bool {
        key == "comentarios_datas_com_conteudo" ||
        key == "leituras_favoritas" || key.hasPrefix("leituras_favoritas_") ||
        key == "leituras_concluidas" || key.hasPrefix("leituras_concluidas_")
    }

    private static func id(_ key: String, _ member: String? = nil) -> String {
        Data(key.utf8).base64EncodedString() + ":" + (member.map { Data($0.utf8).base64EncodedString() } ?? "-")
    }

    private static func encodeValue(_ value: Any) -> Data? {
        try? PropertyListSerialization.data(fromPropertyList: ["value": value], format: .binary, options: 0)
    }

    private static func decodeValue(_ data: Data?) -> Any? {
        guard let data,
              let wrapper = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        return wrapper["value"]
    }

    var values: [String: Any] {
        var result: [String: Any] = [:]
        for record in records.values where record.member == nil {
            if let value = Self.decodeValue(record.value) { result[record.key] = value }
        }
        for key in result.keys where Self.isSet(key) {
            result[key] = records.values.filter { $0.key == key && $0.member != nil && $0.value != nil }
                .compactMap(\.member).sorted()
        }
        return result
    }

    mutating func capture(_ values: [String: Any], now: Date = Date(), revision: String = UUID().uuidString,
                          managedKeys: Set<String>? = nil) {
        var flattened: [String: Record] = [:]
        let timestamp = max(now.timeIntervalSince1970, (records.values.map(\.timestamp).max() ?? 0) + 0.000_001)
        for (key, value) in values {
            let isSet = Self.isSet(key) && value is [String]
            flattened[Self.id(key)] = Record(key: key, member: nil, value: Self.encodeValue(isSet ? [String]() : value), timestamp: timestamp, revision: revision)
            if isSet, let members = value as? [String] {
                for member in Set(members) {
                    flattened[Self.id(key, member)] = Record(key: key, member: member, value: Self.encodeValue(true), timestamp: timestamp, revision: revision)
                }
            }
        }
        for id in Set(records.keys).union(flattened.keys) {
            let existing = records[id]
            if let managedKeys, let key = (existing ?? flattened[id])?.key, !managedKeys.contains(key) { continue }
            if existing?.value == flattened[id]?.value { continue }
            if let next = flattened[id] { records[id] = next }
            else if let existing {
                records[id] = Record(key: existing.key, member: existing.member, value: nil, timestamp: timestamp, revision: revision)
            }
        }
    }

    mutating func merge(_ incoming: Self) {
        for (id, record) in incoming.records {
            if let local = records[id], !record.newer(than: local) { continue }
            records[id] = record
        }
    }

    static func decode(_ data: Data) -> Self? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        if let version = plist["versao"] as? Int, version >= 3 {
            guard version == 3, let records = plist["registros"] as? Data else { return nil }
            return try? PropertyListDecoder().decode(Self.self, from: records)
        }
        var result = Self()
        result.capture(plist["dados"] as? [String: Any] ?? plist,
                       now: plist["atualizadoEm"] as? Date ?? Date(timeIntervalSince1970: 0), revision: "legacy")
        return result
    }

    func encoded() throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try PropertyListSerialization.data(fromPropertyList: [
            "versao": 3,
            "atualizadoEm": Date(timeIntervalSince1970: records.values.map(\.timestamp).max() ?? 0),
            "dados": values,
            "registros": try encoder.encode(self)
        ], format: .binary, options: 0)
    }
}
