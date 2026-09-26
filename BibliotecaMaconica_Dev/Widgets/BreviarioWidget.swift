import SwiftUI
import WidgetKit

struct BreviarioWidgetEntry: TimelineEntry {
    let date: Date
    let leituras: [BreviarioSnapshot]

    var leituraPrincipal: BreviarioSnapshot { leituras.first ?? .vazio }
}

struct BreviarioWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> BreviarioWidgetEntry {
        BreviarioWidgetEntry(date: Date(), leituras: [.vazio])
    }

    func getSnapshot(in context: Context, completion: @escaping (BreviarioWidgetEntry) -> Void) {
        completion(BreviarioWidgetEntry(date: Date(), leituras: BreviarioSnapshotProvider.leiturasDoDia()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreviarioWidgetEntry>) -> Void) {
        let agora = Date()
        let entrada = BreviarioWidgetEntry(
            date: agora,
            leituras: BreviarioSnapshotProvider.leiturasDoDia(data: agora)
        )
        let proximaAtualizacao = Calendar.current.date(byAdding: .hour, value: 6, to: agora) ?? agora

        completion(Timeline(entries: [entrada], policy: .after(proximaAtualizacao)))
    }
}

struct BreviarioWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: BreviarioWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                widgetPequeno
            case .systemMedium:
                widgetMedio
            case .systemLarge:
                widgetGrande
            case .accessoryRectangular:
                acessorioRetangular
            case .accessoryInline:
                Text(entry.leituras.prefix(2).map { "\($0.autor): \($0.titulo)" }.joined(separator: " • "))
            case .accessoryCircular:
                acessorioCircular
            default:
                widgetPequeno
            }
        }
        .containerBackground(fundoWidget, for: .widget)
        .widgetURL(entry.leituraPrincipal.deepLink)
    }

    private var widgetPequeno: some View {
        VStack(alignment: .leading, spacing: 8) {
            simbolo

            Spacer(minLength: 2)

            Text(entry.leituraPrincipal.dataPorExtenso)
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(Array(entry.leituras.prefix(2)), id: \.obraID) { leitura in
                leituraCompacta(leitura, linhas: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var widgetMedio: some View {
        HStack(alignment: .top, spacing: 14) {
            simboloGrande

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.leituraPrincipal.dataPorExtenso)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(Array(entry.leituras.prefix(2)), id: \.obraID) { leitura in
                    leituraCompacta(leitura, linhas: 1)
                    if leitura.obraID != entry.leituras.prefix(2).last?.obraID { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var widgetGrande: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.leituraPrincipal.dataPorExtenso)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Leituras dos dois Breviários")
                        .font(.title3).fontWeight(.semibold)
                }

                Spacer()
                simbolo
            }

            Divider()

            ForEach(Array(entry.leituras.prefix(2)), id: \.obraID) { leitura in
                VStack(alignment: .leading, spacing: 4) {
                    leituraCompacta(leitura, linhas: 1)
                    Text(leitura.resumo).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                }
                if leitura.obraID != entry.leituras.prefix(2).last?.obraID { Divider() }
            }

            Spacer(minLength: 0)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var acessorioRetangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.leituraPrincipal.dataPorExtenso)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(entry.leituras.prefix(2).map { $0.titulo }.joined(separator: " • "))
                .font(.caption).lineLimit(2).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var acessorioCircular: some View {
        VStack(spacing: 2) {
            Image(systemName: "book.closed")
                .font(.caption)

            Text(entry.leituraPrincipal.data.prefix(2))
                .font(.headline)
                .fontWeight(.bold)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private func leituraCompacta(_ leitura: BreviarioSnapshot, linhas: Int) -> some View {
        let conteudo = VStack(alignment: .leading, spacing: 1) {
            Text(leitura.autor)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(leitura.titulo)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(linhas)
                .minimumScaleFactor(0.72)
        }
        if let destino = leitura.deepLink {
            Link(destination: destino) { conteudo }
        } else {
            conteudo
        }
    }

    private var simbolo: some View {
        ZStack {
            Circle()
                .fill(.yellow.opacity(0.16))
            Image(systemName: "compass.drawing")
                .font(.title3)
                .foregroundStyle(.yellow)
        }
        .frame(width: 34, height: 34)
    }

    private var simboloGrande: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.yellow.opacity(0.16))
            Image(systemName: "compass.drawing")
                .font(.title2)
                .foregroundStyle(.yellow)
        }
        .frame(width: 52, height: 52)
    }

    private var fundoWidget: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.06, blue: 0.06),
                Color(red: 0.13, green: 0.11, blue: 0.07)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BreviarioWidget: Widget {
    let kind = "BreviarioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BreviarioWidgetProvider()) { entry in
            BreviarioWidgetView(entry: entry)
                .padding()
        }
        .configurationDisplayName("Biblioteca Maçônica")
        .description("Mostra as leituras diárias dos dois Breviários e abre diretamente cada texto.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

@main
struct BreviarioWidgetBundle: WidgetBundle {
    var body: some Widget {
        BreviarioWidget()
    }
}
