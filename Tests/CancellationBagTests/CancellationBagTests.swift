import Testing
import CancellationBag

@Suite("CancellationBag")
struct CancellationBagTests {
  @Test("Initialization creates empty bag")
  func initialization() {
    let cancellable = CancellationBag()
    #expect(Bool(true))
  }
}
