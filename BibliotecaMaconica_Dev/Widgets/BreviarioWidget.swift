import SwiftUI
import WidgetKit

struct BreviarioWidgetEntry: TimelineEntry {
    let date: Date
    let leitura: BreviarioSnapshot
}

struct BreviarioWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> BreviarioWidgetEntry {
        BreviarioWidgetEntry(date: Date(), leitura: .vazio)
    }

    func getSnapshot(in context: Context, completion: @escaping (BreviarioWidgetEntry) -> Void) {
        completion(BreviarioWidgetEntry(date: Date(), leitura: BreviarioSnapshotProvider.leituraDoDia()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BreviarioWidgetEntry>) -> Void) {
        let agora = Date()
        let entrada = BreviarioWidgetEntry(
            date: agora,
            leitura: BreviarioSnapshotProvider.leituraDoDia(data: agora)
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
                Text("\(entry.leitura.dataPorExtenso) - \(entry.leitura.titulo)")
            case .accessoryCircular:
                acessorioCircular
            default:
                widgetPequeno
            }
        }
        .containerBackground(fundoWidget, for: .widget)
        .widgetURL(entry.leitura.deepLink)
    }

    private var widgetPequeno: some View {
        VStack(alignment: .leading, spacing: 8) {
            simbolo

            Spacer(minLength: 2)

            Text(entry.leitura.dataPorExtenso)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(entry.leitura.titulo)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(4)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var widgetMedio: some View {
        HStack(alignment: .top, spacing: 14) {
            simboloGrande

            VStack(alignment: .leading, spacing: 7) {
                Text(entry.leitura.dataPorExtenso)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(entry.leitura.titulo)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Text(entry.leitura.resumo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var widgetGrande: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.leitura.dataPorExtenso)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(entry.leitura.titulo)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                }

                Spacer()
                simbolo
            }

            Divider()

            Text(entry.leitura.trecho)
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.82))
                .lineLimit(9)

            Spacer(minLength: 0)

            Text(entry.leitura.autor)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var acessorioRetangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.leitura.dataPorExtenso)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(entry.leitura.titulo)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var acessorioCircular: some View {
        VStack(spacing: 2) {
            Image(systemName: "book.closed")
                .font(.caption)

            Text(entry.leitura.data.prefix(2))
                .font(.headline)
                .fontWeight(.bold)
                .minimumScaleFactor(0.8)
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
        .description("Mostra a leitura do dia e abre diretamente o texto correspondente.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

@main
struct BreviarioWidgetBundle: WidgetBundle {
    var body: some Widget {
        BreviarioWidget()
    }
}
