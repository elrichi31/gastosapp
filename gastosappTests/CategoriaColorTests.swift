import SwiftUI
import Testing
@testable import Zenlor

struct CategoriaColorTests {
    @Test func commonCategoriesHaveDistinctColorsWhateverTheirIDs() {
        // Ids separados por el tamaño de la paleta: antes caían en el mismo color.
        let names = ["Alimentación", "Transporte", "Hogar", "Ocio", "Salud", "Educación", "Otros"]
        let colors = names.enumerated().map { Categoria(id: 1 + $0.offset * 6, nombre: $0.element).color }
        for i in colors.indices {
            for j in colors.indices where j > i {
                #expect(colors[i] != colors[j], "\(names[i]) y \(names[j]) tienen el mismo color")
            }
        }
    }
}
