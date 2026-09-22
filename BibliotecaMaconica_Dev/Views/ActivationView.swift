import SwiftUI
import UIKit
import CryptoKit

enum ActivationCodeGenerator {
    private static let codigoRevisaoApple = "BMXI-APPLE-2026"

    static func codigoDoDia(_ date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pt_BR")

        let components = calendar.dateComponents([.day, .month, .year], from: date)
        let dia = components.day ?? 1
        let mes = components.month ?? 1
        let ano = components.year ?? 2026
        let semente = (dia * 9_283) + (mes * 6_151) + (ano * 313) + 7_349
        let mistura = semente ^ ((dia + 17) * (mes + 29) * 97)
        let digitos = abs(mistura) % 10_000

        return String(format: "BMXI-%02d%02d-%04d", dia, mes, digitos)
    }

    static func codigoValido(_ codigo: String, para date: Date = Date()) -> Bool {
        let codigoNormalizado = normalizar(codigo)
        return codigoNormalizado == normalizar(codigoDoDia(date))
            || codigoNormalizado == normalizar(codigoRevisaoApple)
    }

    static func dataPorExtenso(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd 'de' MMMM 'de' yyyy"
        return formatter.string(from: date)
    }

    private static func normalizar(_ codigo: String) -> String {
        codigo
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

enum ActivationAdminPassword {
    private static let senhaHash = "c55a6c39f3e28eea11af61edc4085dd031a3a81213c84497384459deb576efbb"

    static func validar(_ senha: String) -> Bool {
        hash(normalizar(senha)) == senhaHash
    }

    private static func normalizar(_ senha: String) -> String {
        senha
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private static func hash(_ texto: String) -> String {
        let digest = SHA256.hash(data: Data(texto.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct ActivationGateView: View {
    @AppStorage("appAtivado") private var appAtivado = false

    private var executandoTesteDeInterface: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
        #else
        false
        #endif
    }

    var body: some View {
        if appAtivado || executandoTesteDeInterface {
            HomeView()
        } else {
            ActivationView {
                appAtivado = true
            }
        }
    }
}

private struct ActivationView: View {
    @State private var codigo = ""
    @State private var mensagem = ""
    @State private var mostrarErro = false
    @State private var mostrandoGeradorAdmin = false
    @FocusState private var campoFocado: Bool

    let onActivated: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.05, blue: 0.04),
                    Color(red: 0.18, green: 0.13, blue: 0.06),
                    Color(red: 0.03, green: 0.03, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 24)

                VStack(spacing: 14) {
                    Image("AppLaunchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                        .onTapGesture(count: 8) {
                            abrirGeradorAdmin()
                        }

                    Text("Biblioteca Maçônica")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("Estudos maçônicos")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.92, green: 0.76, blue: 0.36))
                }
                .onTapGesture(count: 8) {
                    abrirGeradorAdmin()
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Código de ativação")
                        .font(.headline)
                        .foregroundStyle(.white)

                    TextField("Digite o código", text: $codigo)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .focused($campoFocado)
                        .submitLabel(.done)
                        .onSubmit(validarCodigo)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button(action: validarCodigo) {
                        Text("Ativar")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.76, green: 0.57, blue: 0.22))
                    .foregroundStyle(.black)

                    if mensagem.isEmpty == false {
                        Text(mensagem)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(mostrarErro ? Color(red: 1.0, green: 0.55, blue: 0.48) : Color(red: 0.62, green: 0.92, blue: 0.68))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(22)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 24)

                Spacer(minLength: 24)
            }
        }
        .onAppear {
            campoFocado = true
        }
        .sheet(isPresented: $mostrandoGeradorAdmin) {
            ActivationAdminProtectedGeneratorView()
        }
    }

    private func validarCodigo() {
        guard ActivationCodeGenerator.codigoValido(codigo) else {
            withAnimation(.easeInOut(duration: 0.2)) {
                mostrarErro = true
                mensagem = "Código inválido para hoje. Verifique e tente novamente."
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            mostrarErro = false
            mensagem = "Ativação concluída."
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onActivated()
        }
    }

    private func abrirGeradorAdmin() {
        campoFocado = false
        mostrandoGeradorAdmin = true
    }

}

struct ActivationAdminProtectedGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var senha = ""
    @State private var acessoLiberado = false
    @State private var mensagem = ""
    @State private var mostrarErro = false
    @FocusState private var campoFocado: Bool

    var body: some View {
        if acessoLiberado {
            ActivationAdminGeneratorView()
        } else {
            NavigationStack {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.07, blue: 0.05),
                            Color(red: 0.23, green: 0.16, blue: 0.06),
                            Color(red: 0.03, green: 0.03, blue: 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 22) {
                        Image("AppLaunchIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)

                        VStack(spacing: 8) {
                            Text("Acesso Restrito")
                                .font(.title2.bold())
                                .foregroundStyle(.white)

                            Text("Digite sua senha administrativa para abrir o gerador.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Senha administrativa")
                                .font(.headline)
                                .foregroundStyle(.white)

                            SecureField("Digite a senha", text: $senha)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .focused($campoFocado)
                                .submitLabel(.done)
                                .onSubmit(validarSenha)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 16)
                                .frame(height: 54)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button(action: validarSenha) {
                                Label("Liberar acesso", systemImage: "lock.open")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.76, green: 0.57, blue: 0.22))
                            .foregroundStyle(.black)

                            if mensagem.isEmpty == false {
                                Text(mensagem)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(mostrarErro ? Color(red: 1.0, green: 0.55, blue: 0.48) : Color(red: 0.62, green: 0.92, blue: 0.68))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .padding(24)
                    .frame(maxWidth: 440)
                }
                .navigationTitle("Proteção")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fechar") {
                            dismiss()
                        }
                        .foregroundStyle(Color(red: 0.92, green: 0.76, blue: 0.36))
                    }
                }
                .onAppear {
                    campoFocado = true
                }
            }
        }
    }

    private func validarSenha() {
        guard ActivationAdminPassword.validar(senha) else {
            withAnimation(.easeInOut(duration: 0.2)) {
                mostrarErro = true
                mensagem = "Senha administrativa inválida."
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            mostrarErro = false
            mensagem = "Acesso liberado."
            acessoLiberado = true
        }
    }
}

struct ActivationAdminGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mensagem = ""

    private var codigoHoje: String {
        ActivationCodeGenerator.codigoDoDia()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.07, blue: 0.05),
                        Color(red: 0.23, green: 0.16, blue: 0.06),
                        Color(red: 0.03, green: 0.03, blue: 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 22) {
                    Image("AppLaunchIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)

                    VStack(spacing: 8) {
                        Text("Gerador de Ativação")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text(ActivationCodeGenerator.dataPorExtenso())
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color(red: 0.92, green: 0.76, blue: 0.36))
                    }

                    VStack(spacing: 14) {
                        Text(codigoHoje)
                            .font(.system(.title2, design: .monospaced).weight(.bold))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity)
                            .frame(height: 66)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(red: 0.92, green: 0.76, blue: 0.36).opacity(0.7), lineWidth: 1)
                            )

                        Button {
                            UIPasteboard.general.string = codigoHoje
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mensagem = "Código copiado."
                            }
                        } label: {
                            Label("Copiar código", systemImage: "doc.on.doc")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.76, green: 0.57, blue: 0.22))
                        .foregroundStyle(.black)

                        if mensagem.isEmpty == false {
                            Text(mensagem)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color(red: 0.62, green: 0.92, blue: 0.68))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("Este código muda diariamente e libera o app apenas uma vez no aparelho ativado.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: 440)
            }
            .navigationTitle("Ativação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                    .foregroundStyle(Color(red: 0.92, green: 0.76, blue: 0.36))
                }
            }
        }
    }
}
