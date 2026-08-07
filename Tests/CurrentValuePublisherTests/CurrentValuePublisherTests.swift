import Testing
import CurrentValuePublisher
import Combine

@Suite("CurrentValuePublisher")
struct CurrentValuePublisherTests {
  @Test("Emits value on subscription")
  func emitsOnSubscribe() {
    let sut = CurrentValuePublisher<Int, Never>(initialValue: 42)
    var received: [Int] = []
    let cancellable = sut.sink { value in received.append(value) }
    #expect(received == [42])
    cancellable.cancel()
  }
}
