import Synchronization

/// A door a test holds shut until it says so, counting who reached it. A test waits for somebody to reach it by the event
/// itself, never by a number of turns: under load a fixed number of turns can run out before the door is reached.
final class HeldDoor: Sendable {
    private struct State {
        var open = true
        var reached = 0
        var held: [CheckedContinuation<Void, Never>] = []
        var watching: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    }

    private let state = Mutex(State())

    func shut() { state.withLock { $0.open = false } }
    var reached: Int { state.withLock { $0.reached } }

    func pass() async {
        await withCheckedContinuation { continuation in
            let (through, arrived) = state.withLock { door -> (Bool, [CheckedContinuation<Void, Never>]) in
                door.reached += 1
                let count = door.reached
                let arrived = door.watching.filter { $0.count <= count }.map(\.continuation)
                door.watching.removeAll { $0.count <= count }
                if door.open { return (true, arrived) }
                door.held.append(continuation)
                return (false, arrived)
            }
            for watcher in arrived { watcher.resume() }
            if through { continuation.resume() }
        }
    }

    func open() {
        let held = state.withLock { door -> [CheckedContinuation<Void, Never>] in
            door.open = true
            defer { door.held = [] }
            return door.held
        }
        for continuation in held { continuation.resume() }
    }

    /// Returns once `count` arrivals have reached the door.
    func awaitReached(_ count: Int = 1) async {
        await withCheckedContinuation { continuation in
            let now = state.withLock { door -> Bool in
                if door.reached >= count { return true }
                door.watching.append((count, continuation))
                return false
            }
            if now { continuation.resume() }
        }
    }
}
