import SwiftUI
import Synchronization

struct Categoria: Identifiable, Hashable, Codable {
    let id: Int
    let nombre: String

    /// Tabla de glifos: cada entrada asocia palabras clave con un símbolo.
    ///
    /// El orden importa — las entradas más específicas van primero, para que
    /// "cafetería" no caiga en "comida" ni "gasolina" en "transporte".
    /// Todos los símbolos son de peso equivalente, para que una lista de
    /// categorías se lea pareja en lugar de alternar trazos gruesos y finos.
    /// Tono de la paleta de categorías, por su posición en `AppTheme.categoryPalette`.
    private enum Tint: Int, Sendable {
        case blue, amber, violet, green, pink, teal, orange, lime, magenta, slate
    }

    /// Tabla de glifos: cada entrada asocia palabras clave con un símbolo y un tono.
    ///
    /// El orden importa — las entradas más específicas van primero, para que
    /// "cafetería" no caiga en "comida" ni "gasolina" en "transporte".
    /// Todos los símbolos son de peso equivalente, para que una lista de
    /// categorías se lea pareja en lugar de alternar trazos gruesos y finos.
    /// Las categorías habituales (Alimentación, Transporte, Hogar, Ocio, Salud,
    /// Educación) tienen tonos distintos entre sí.
    private static let glyphTable: [(keywords: [String], symbol: String, tint: Tint)] = [
        (["restaurante", "cafe", "cafeteria", "bar", "bebida"], "cup.and.saucer.fill", .amber),
        (["comida", "aliment", "mercado", "super", "despensa", "groceries"], "fork.knife", .orange),
        (["gasolina", "combustible", "nafta", "bencina"], "fuelpump.fill", .teal),
        (["transporte", "movilidad", "uber", "taxi", "bus", "metro", "pasaje"], "car.fill", .blue),
        (["viaje", "vuelo", "hotel", "vacacion", "turismo"], "airplane", .teal),
        (["renta", "alquiler", "hipoteca", "arriendo"], "key.fill", .green),
        (["luz", "agua", "internet", "telefono", "electricidad", "gas", "servicio"], "bolt.fill", .amber),
        (["hogar", "casa", "mueble", "limpieza"], "house.fill", .green),
        (["suscrip", "streaming", "netflix", "spotify"], "play.rectangle.fill", .violet),
        (["ocio", "entreten", "diversion", "cine", "juego", "videojuego"], "gamecontroller.fill", .magenta),
        (["gym", "gimnasio", "deporte", "ejercicio", "fitness"], "figure.run", .lime),
        (["salud", "farmacia", "medic", "doctor", "clinica", "hospital"], "cross.case.fill", .pink),
        (["seguro", "poliza"], "shield.fill", .slate),
        (["educ", "curso", "libro", "escuela", "universidad", "colegio"], "graduationcap.fill", .violet),
        (["ropa", "vestuario", "moda", "zapato", "calzado"], "tshirt.fill", .magenta),
        (["belleza", "peluqueria", "estetica", "barberia"], "scissors", .pink),
        (["mascota", "perro", "gato", "veterinar"], "pawprint.fill", .amber),
        (["bebe", "niño", "nino", "guarderia", "infantil"], "figure.and.child.holdinghands", .lime),
        (["tecnolog", "electronic", "computador", "celular", "software"], "laptopcomputer", .teal),
        (["regalo", "cumple", "navidad"], "gift.fill", .pink),
        (["donacion", "caridad", "ayuda"], "heart.fill", .pink),
        (["impuesto", "tasa", "multa", "tramite"], "doc.text.fill", .slate),
        (["banco", "comision", "interes", "prestamo", "credito"], "building.columns.fill", .slate),
        (["ahorro", "inversion", "fondo"], "chart.line.uptrend.xyaxis", .green),
        (["trabajo", "oficina", "negocio"], "briefcase.fill", .blue)
    ]

    /// Símbolo y tono resueltos a partir del nombre.
    private struct Style: Sendable {
        let symbol: String?
        let tint: Tint?
    }

    /// Resolver el estilo normaliza el nombre y recorre toda la tabla, y las
    /// listas lo piden varias veces por fila en cada dibujado: se guarda por
    /// nombre, que sólo hay unas pocas categorías.
    private static let styleCache = Mutex<[String: Style]>([:])

    private var style: Style {
        if let cached = Self.styleCache.withLock({ $0[nombre] }) { return cached }
        let key = nombre.normalizedLookupKey
        let entry = Self.glyphTable.first { entry in
            entry.keywords.contains { key.contains($0) }
        }
        let resolved = Style(
            symbol: entry?.symbol,
            tint: entry?.tint ?? (key.contains("otro") ? .slate : nil)
        )
        Self.styleCache.withLock { $0[nombre] = resolved }
        return resolved
    }

    /// Símbolo dedicado para la categoría, o `nil` si ninguna palabra clave coincide.
    ///
    /// Las categorías sin coincidencia se dibujan con su inicial: es preferible
    /// una letra legible a repetir el mismo icono genérico en toda la lista.
    var symbolName: String? {
        style.symbol
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

    /// Tinte estable de la categoría.
    ///
    /// Sale de `AppTheme.categoryPalette`: tonos de claridad parecida y matiz
    /// bien separado, para que un desglose con varias categorías se lea sin leyenda.
    /// Va por el tipo de categoría y no por su identificador: con el módulo del
    /// id, Alimentación y Transporte del servidor caían en el mismo color.
    var color: Color {
        AppTheme.categoryColor(at: style.tint?.rawValue ?? abs(id))
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
