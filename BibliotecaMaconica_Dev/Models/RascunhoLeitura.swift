import SwiftUI
import Observation

/// Texts being typed in the reading. Only the views that show them observe this object, so each
/// keystroke redraws the editor instead of the whole home screen with all its tabs. Actions (save,
/// drafts, share) read the latest value directly, with no delayed copy that could lose keystrokes.
@Observable
final class RascunhoLeitura {
    var comentario = ""
    var reflexao = ""
}

/// Hands a binding to one draft field to its editor, observing only that field.
struct CampoRascunho<Conteudo: View>: View {
    @Bindable var rascunho: RascunhoLeitura
    let campo: ReferenceWritableKeyPath<RascunhoLeitura, String>
    @ViewBuilder let conteudo: (Binding<String>) -> Conteudo

    var body: some View {
        // Reading the field here is what makes this view, and only it, follow the typing.
        let _ = rascunho[keyPath: campo]
        conteudo($rascunho[dynamicMember: campo])
    }
}

/// Enables an action only while the comment has text, observing the comment in this small view.
struct SeHaComentario<Conteudo: View>: View {
    let rascunho: RascunhoLeitura
    @ViewBuilder let conteudo: () -> Conteudo

    var body: some View {
        conteudo().disabled(rascunho.comentario.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
