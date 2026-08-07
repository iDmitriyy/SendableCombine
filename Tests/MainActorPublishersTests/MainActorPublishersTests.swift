import Testing
import MainActorPublishers
import Combine

@Suite("MainActorPublishers")
struct MainActorPublishersTests {
  @Test("Driver type exists")
  func driverTypeExists() {
    let _: Driver<Int, Never> = Driver(Just(42))
    #expect(Bool(true))
  }

  @Test("Signal type exists")
  func signalTypeExists() {
    let _: Signal<Int, Never> = Signal(Just(42))
    #expect(Bool(true))
  }
}
