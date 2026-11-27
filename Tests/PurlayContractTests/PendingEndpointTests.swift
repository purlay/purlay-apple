import Testing

@testable import PurlayContract

/// QA (PR #7, TD-026): the routes written by hand in `PendingEndpoints.swift` cannot drift silently. The compile-time collision
/// the file relies on only fires if the generated id is the same; these fail the build's tests whatever the generator names it.
@Suite("routes written by hand until a pin brings them")
struct PendingEndpointTests {
    private static let pending = [Endpoints.eraseMyAccount]

    @Test(
        "no pending route is also in the generated table, under any id: once a pin brings it, the hand-written one goes"
    )
    func notYetGenerated() {
        for route in Self.pending {
            let generated = Endpoints.all.first { $0.method == route.method && $0.path == route.path }
            #expect(
                generated == nil,
                "\(route.method) \(route.path) is now generated as \(generated?.id ?? ""): delete it from PendingEndpoints.swift (TD-026)"
            )
            #expect(!Endpoints.all.contains { $0.id == route.id })
        }
    }

    @Test("a pending route names schemas the contract has, as a generated one must")
    func schemasExist() {
        for route in Self.pending {
            if case .schema(let name)? = route.body { #expect(ContractRegistry.roundTrips[name] != nil, "\(name)") }
            for case .schema(let name) in route.responses.values {
                #expect(ContractRegistry.roundTrips[name] != nil, "\(name)")
            }
        }
    }
}
