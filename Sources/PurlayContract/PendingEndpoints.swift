/// Routes the server has built and `API.md` states, that the pinned contract's endpoint table does not carry yet, written by
/// hand until a pin brings them (TD-026). The body and the answer are the contract's own types. When the generated
/// `Endpoints` gains a name here, the two collide and the entry is deleted.
extension Endpoints {
    /// `POST /api/me/erase`: the caller erases their own account, their username typed as `confirm` (D-139 §5).
    public static let eraseMyAccount = EndpointSpec(
        id: "eraseMyAccount", method: "POST", path: "/api/me/erase", auth: .session,
        query: nil, body: .schema("EraseAccountRequest"),
        responses: [204: .empty])
}
