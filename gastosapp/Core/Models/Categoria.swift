import SwiftUI

struct Categoria: Identifiable, Hashable, Codable {
    let id: Int
    let nombre: String

    /// Tabla de glifos: cada entrada asocia palabras clave con un símbolo.
    ///
    /// El orden importa — las entradas más específicas van primero, para que
    /// "cafetería" no caiga en "comida" ni "gasolina" en "transporte".
    /// Todos los símbolos son de peso equivalente, para que una lista de
    /// categorías se lea pareja en lugar de alternar trazos gruesos y finos.
    private static let glyphTable: [(keywords: [String], symbol: String)] = [
        (["restaurante", "cafe", "cafeteria", "bar", "bebida"], "cup.and.saucer.fill"),
        (["comida", "aliment", "mercado", "super", "despensa", "groceries"], "fork.knife"),
        (["gasolina", "combustible", "nafta", "bencina"], "fuelpump.fill"),
        (["transporte", "movilidad", "uber", "taxi", "bus", "metro", "pasaje"], "car.fill"),
        (["viaje", "vuelo", "hotel", "vacacion", "turismo"], "airplane"),
        (["renta", "alquiler", "hipoteca", "arriendo"], "key.fill"),
        (["luz", "agua", "internet", "telefono", "electricidad", "gas", "servicio"], "bolt.fill"),
        (["hogar", "casa", "mueble", "limpieza"], "house.fill"),
        (["suscrip", "streaming", "netflix", "spotify"], "play.rectangle.fill"),
        (["ocio", "entreten", "diversion", "cine", "juego", "videojuego"], "gamecontroller.fill"),
        (["gym", "gimnasio", "deporte", "ejercicio", "fitness"], "figure.run"),
        (["salud", "farmacia", "medic", "doctor", "clinica", "hospital"], "cross.case.fill"),
        (["seguro", "poliza"], "shield.fill"),
        (["educ", "curso", "libro", "escuela", "universidad", "colegio"], "graduationcap.fill"),
        (["ropa", "vestuario", "moda", "zapato", "calzado"], "tshirt.fill"),
        (["belleza", "peluqueria", "estetica", "barberia"], "scissors"),
        (["mascota", "perro", "gato", "veterinar"], "pawprint.fill"),
        (["bebe", "niño", "nino", "guarderia", "infantil"], "figure.and.child.holdinghands"),
        (["tecnolog", "electronic", "computador", "celular", "software"], "laptopcomputer"),
        (["regalo", "cumple", "navidad"], "gift.fill"),
        (["donacion", "caridad", "ayuda"], "heart.fill"),
        (["impuesto", "tasa", "multa", "tramite"], "doc.text.fill"),
        (["banco", "comision", "interes", "prestamo", "credito"], "building.columns.fill"),
        (["ahorro", "inversion", "fondo"], "chart.line.uptrend.xyaxis"),
        (["trabajo", "oficina", "negocio"], "briefcase.fill")
    ]

    /// Símbolo dedicado para la categoría, o `nil` si ninguna palabra clave coincide.
    ///
    /// Las categorías sin coincidencia se dibujan con su inicial: es preferible
    /// una letra legible a repetir el mismo icono genérico en toda la lista.
    var symbolName: String? {
        let key = nombre.normalizedLookupKey
        return Self.glyphTable.first { entry in
            entry.keywords.contains { key.contains($0) }
        }?.symbol
    }

    /// Inicial de la categoría, para las que no tienen símbolo propio.
    var monogram: String {
        let trimmed = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    /// Símbolo con respaldo genérico, para los sitios que necesitan un `systemName`.
    var icono: String {
        symbolName ?? "circle.grid.2x2.fill"
    }

    /// Tinte estable de la categoría, derivado de su identificador.
    ///
    /// Sale de `AppTheme.categoryPalette`: tonos de claridad parecida y matiz
    /// bien separado, para que un desglose con varias categorías se lea sin leyenda.
    var color: Color {
        AppTheme.categoryColor(at: abs(id))
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
