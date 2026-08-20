import Foundation
import Observation

@Observable
final class SubscriptionStore {
    var suscripciones: [Subscription] = []

    func add(_ s: Subscription) {
        suscripciones.insert(s, at: 0)
    }

    func remove(id: UUID) {
        suscripciones.removeAll { $0.id == id }
    }

    var totalMensual: Double {
        suscripciones.reduce(0) { $0 + $1.costoMensualEquivalente }
    }

    var totalAnual: Double {
        totalMensual * 12
    }
}
