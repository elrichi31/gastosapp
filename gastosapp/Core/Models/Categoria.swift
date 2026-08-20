import SwiftUI

struct Categoria: Identifiable, Hashable, Codable {
    let id: Int
    let nombre: String

    var icono: String {
        let key = nombre.normalizedLookupKey
        if key.contains("comida") || key.contains("aliment") || key.contains("mercado") {
            return "fork.knife"
        }
        if key.contains("transporte") || key.contains("movilidad") || key.contains("uber") || key.contains("gasolina") {
            return "car.fill"
        }
        if key.contains("hogar") || key.contains("casa") || key.contains("servicio") {
            return "house.fill"
        }
        if key.contains("ocio") || key.contains("entreten") || key.contains("diversion") {
            return "gamecontroller.fill"
        }
        if key.contains("salud") || key.contains("farmacia") || key.contains("medic") {
            return "heart.fill"
        }
        if key.contains("educ") || key.contains("curso") || key.contains("libro") {
            return "book.fill"
        }
        if key.contains("suscrip") || key.contains("streaming") {
            return "repeat.circle.fill"
        }
        return "square.grid.2x2.fill"
    }

    var color: Color {
        let key = nombre.normalizedLookupKey
        if key.contains("comida") || key.contains("aliment") || key.contains("mercado") {
            return AppTheme.warning
        }
        if key.contains("transporte") || key.contains("movilidad") || key.contains("uber") || key.contains("gasolina") {
            return .blue
        }
        if key.contains("hogar") || key.contains("casa") || key.contains("servicio") {
            return AppTheme.accent
        }
        if key.contains("ocio") || key.contains("entreten") || key.contains("diversion") {
            return .pink
        }
        if key.contains("salud") || key.contains("farmacia") || key.contains("medic") {
            return AppTheme.negative
        }
        if key.contains("educ") || key.contains("curso") || key.contains("libro") {
            return .indigo
        }
        if key.contains("suscrip") || key.contains("streaming") {
            return AppTheme.secondaryAccent
        }
        return .gray
    }

    static let fallback: [Categoria] = [
        Categoria(id: 1, nombre: "Alimentación"),
        Categoria(id: 2, nombre: "Transporte"),
        Categoria(id: 3, nombre: "Hogar"),
        Categoria(id: 4, nombre: "Ocio"),
        Categoria(id: 5, nombre: "Salud"),
        Categoria(id: 6, nombre: "Educación"),
        Categoria(id: 7, nombre: "Otros")
    ]

    static var placeholder: Categoria {
        fallback.first ?? Categoria(id: 0, nombre: "Otros")
    }
}
