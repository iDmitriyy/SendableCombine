import Testing
import CurrentValuePublisher
import Combine

@Suite("AnyCurrentValuePublisher")
struct AnyCurrentValuePublisherTests {
  @Test("Emits value on subscription")
  func emitsOnSubscribe() async {
    let subject = CurrentValueSubject<Int, Never>(42)
    let publisher = subject.asCurrentValuePublisher()

    let received = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
      var values = [Int]()
      var cancellable: AnyCancellable?
      cancellable = publisher.sink { value in
        values.append(value)
        if values.count >= 1 {
          continuation.resume(returning: values)
        }
      }
      _ = cancellable
    }

    #expect(received == [42])
  }

  @Test("Receives subsequent values after subscription")
  func receivesSubsequentValues() async {
    let subject = CurrentValueSubject<Int, Never>(42)
    let publisher = subject.asCurrentValuePublisher()

    let received = await withCheckedContinuation { (continuation: CheckedContinuation<[Int], Never>) in
      var values = [Int]()
      var cancellable: AnyCancellable?
      cancellable = publisher.sink { value in
        values.append(value)
        if values.count >= 2 {
          continuation.resume(returning: values)
        }
      }
      _ = cancellable
    }

    subject.send(100)

    #expect(received == [42, 100])
  }
}