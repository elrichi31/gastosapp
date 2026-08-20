import Foundation

func isConnectivityError(_ error: Error) -> Bool {
    if let urlError = error as? URLError {
        return urlError.isConnectivityIssue
    }
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain {
        return URLError(URLError.Code(rawValue: nsError.code)).isConnectivityIssue
    }
    return false
}

func isCancellationError(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let urlError = error as? URLError {
        return urlError.code == .cancelled
    }
    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == URLError.cancelled.rawValue
}

extension URLError {
    var isConnectivityIssue: Bool {
        switch code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .timedOut,
             .internationalRoamingOff,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }
}
