//  Plantilla de configuración local.
//
//  Cópiala a `gastosapp/Configuration/LocalAPIConfig.swift` y reemplaza la URL
//  por la de tu backend. Ese destino está en .gitignore a propósito: cada
//  entorno apunta a un servidor distinto y no debe viajar en el repositorio.
//
//  Este archivo vive en la raíz y no dentro de `gastosapp/` porque ese
//  directorio es un grupo sincronizado de Xcode: cualquier .swift ahí dentro
//  se compilaría y chocaría con el archivo real.

import Foundation

enum LocalAPIConfig {
    static let baseURL = "https://tu-backend.ejemplo.com"

    static var registerURL: URL {
        URL(string: "\(baseURL)/auth/register")!
    }
}
