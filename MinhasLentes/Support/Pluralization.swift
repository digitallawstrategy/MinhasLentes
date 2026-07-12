import Foundation

/// Pluralização em português — nunca derivada automaticamente do singular (o português tem
/// plurais irregulares como "ão" → "ões", sem sufixo previsível), então cada chamada informa as
/// duas formas por extenso. Existe para banir "dia(s)"/"par(es)"/"importado(s)" — que leem como
/// texto de formulário interno, não como um app pronto — do restante do app.
enum Pluralization {
    /// "1 dia" / "5 dias". Para o caso comum de um número seguido do substantivo.
    static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(word(n, singular, plural))"
    }

    /// Só a palavra concordada, para frases onde o número não vem imediatamente antes
    /// (ex.: "3 de 10 unidades").
    static func word(_ n: Int, _ singular: String, _ plural: String) -> String {
        n == 1 ? singular : plural
    }
}
