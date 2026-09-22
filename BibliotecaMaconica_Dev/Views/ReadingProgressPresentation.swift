import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension HomeView {
var painelProgressoAnual: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progresso anual")
                        .font(.headline)
                        .foregroundStyle(textoApp)

                    Text("\(totalLidas) de \(totalLeituras) leituras concluídas")
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                }

                Spacer()

                Text("\(percentualLeitura)%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(destaqueApp)
            }

            ProgressView(value: progressoLeitura)
                .tint(destaqueApp)
                .accessibilityLabel("Progresso anual")
                .accessibilityValue("\(percentualLeitura)%")

            HStack(spacing: 10) {
                Label("\(sequenciaAtual) dias em sequência", systemImage: "flame")
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)

                Spacer()

                Button {
                    filtroLeitura = .naoLidos
                    abrirBreviario()
                } label: {
                    Label("Continuar", systemImage: "arrow.right.circle")
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var painelProgressoSemanal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Semana atual")
                        .font(.headline)
                        .foregroundStyle(textoApp)

                    Text("\(totalLidasSemanaAtual) de \(itensSemanaAtual.count) leituras da semana")
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                }

                Spacer()

                Text("\(percentualSemanaAtual)%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(destaqueApp)
            }

            ProgressView(value: progressoSemanaAtual)
                .tint(destaqueApp)
                .accessibilityLabel("Progresso semanal")
                .accessibilityValue("\(percentualSemanaAtual)%")

            HStack(spacing: 8) {
                ForEach(itensSemanaAtual) { item in
                    Circle()
                        .fill(leiturasConcluidas.contains(item.data) ? Color.green : textoApp.opacity(0.18))
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("\(item.data) \(leiturasConcluidas.contains(item.data) ? "lido" : "pendente")")
                }

                Spacer()

                Button {
                    abrirProximaLeituraDaSemana()
                } label: {
                    Label("Continuar semana", systemImage: "arrow.right.circle")
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(itensSemanaAtual.isEmpty || itensSemanaAtual.allSatisfy { leiturasConcluidas.contains($0.data) })
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var painelProgressoMensal: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(nomeMesAtual)
                        .font(.headline)
                        .foregroundStyle(textoApp)

                    Text("\(totalLidasMesAtual) de \(itensMesAtual.count) leituras do mês")
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                }

                Spacer()

                Text("\(percentualMesAtual)%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(destaqueApp)
            }

            ProgressView(value: progressoMesAtual)
                .tint(destaqueApp)
                .accessibilityLabel("Progresso mensal")
                .accessibilityValue("\(percentualMesAtual)%")

            HStack(spacing: 10) {
                Label("Meta do mês", systemImage: "calendar.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)

                Spacer()

                Button {
                    abrirProximaLeituraDoMes()
                } label: {
                    Label("Continuar mês", systemImage: "arrow.right.circle")
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(itensMesAtual.allSatisfy { leiturasConcluidas.contains($0.data) })
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var calendarioMensalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Escolher data", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(textoApp)

                Spacer()

                Text(nomeMesAtual)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(destaqueApp)
            }

            HStack(spacing: 10) {
                Button {
                    mudarMesCalendario(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 34, height: 32)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Mês anterior")

                Button {
                    calendarioMesExibido = Date()
                    atualizarResumoNavegacaoCache()
                } label: {
                    Label("Hoje", systemImage: "calendar.badge.clock")
                }
                .buttonStyle(.bordered)

                Button {
                    mudarMesCalendario(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 34, height: 32)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Próximo mês")

                Spacer()
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
                spacing: 6
            ) {
                ForEach(diasSemanaCalendario, id: \.self) { dia in
                    Text(dia)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(textoSecundarioApp)
                        .frame(maxWidth: .infinity)
                }

                ForEach(diasCalendarioMesAtual) { dia in
                    if let item = dia.item, let numeroDia = dia.dia {
                        Button {
                            abrirLeitura(item)
                        } label: {
                            diaCalendarioCelula(
                                numero: numeroDia,
                                lido: leiturasConcluidas.contains(item.data),
                                favorito: favoritos.contains(item.data),
                                hoje: item.data == dataHojeBreviario
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Abrir leitura de \(item.data)")
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }

            HStack(spacing: 12) {
                legendaCalendario("Hoje", cor: destaqueApp)
                legendaCalendario("Lido", cor: .green)
                legendaCalendario("Favorito", cor: .orange)
            }
        }
        .padding()
        .background(temaApp.painel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func diaCalendarioCelula(
        numero: Int,
        lido: Bool,
        favorito: Bool,
        hoje: Bool
    ) -> some View {
        VStack(spacing: 4) {
            Text("\(numero)")
                .font(.subheadline)
                .fontWeight(hoje ? .bold : .semibold)
                .foregroundStyle(temaApp == .sepia ? .black : (hoje ? .black : textoApp))

            HStack(spacing: 3) {
                Circle()
                    .fill(lido ? Color.green : textoApp.opacity(0.18))
                    .frame(width: 5, height: 5)

                if favorito {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(hoje ? destaqueApp.opacity(0.86) : temaApp.painel)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(favorito ? Color.orange.opacity(0.9) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func legendaCalendario(_ texto: String, cor: Color) -> some View {
        Label {
            Text(texto)
                .font(.caption2)
                .foregroundStyle(textoSecundarioApp)
        } icon: {
            Circle()
                .fill(cor)
                .frame(width: 7, height: 7)
        }
    }

    func proximaLeituraCard(_ item: BreviarioItem) -> some View {
        Button {
            abrirLeitura(item)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Próxima leitura", systemImage: "sparkle.magnifyingglass")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(destaqueApp)

                    Spacer()

                    Label(item.tempoLeituraEstimado, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(textoSecundarioApp)
                }

                Text(item.data)
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)

                Text(item.titulo)
                    .font(.headline)
                    .foregroundStyle(textoApp)

                Text(item.resumo)
                    .font(.caption)
                    .foregroundStyle(textoSecundarioApp)
                    .lineLimit(3)

                Label("Abrir leitura sugerida", systemImage: "arrow.right.circle")
                    .font(.caption)
                    .foregroundStyle(destaqueApp)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(temaApp.painel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
