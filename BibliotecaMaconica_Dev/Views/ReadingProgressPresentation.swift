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

}
