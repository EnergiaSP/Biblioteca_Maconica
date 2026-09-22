import Foundation

struct IndiceRemissivoEntry: Codable, Identifiable, Equatable {

    let id: Int
    let termo: String
    let paginas: [Int]
    let datas: [String]

    var paginasFormatadas: String {
        paginas.map(String.init).joined(separator: ", ")
    }

    var datasBusca: String {
        datas.joined(separator: ", ")
    }
}

struct BreviarioData: Codable {

    let itens: [BreviarioItem]
    let indiceRemissivo: [IndiceRemissivoEntry]
}
