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

  @Test("previousAndCurrent pairs each value with its predecessor")
  func previousAndCurrent() {
    let subject = CurrentValueSubject<Int, Never>(1)
    let publisher = subject.asCurrentValuePublisher().previousAndCurrent()

    let recorder = ValueRecorder<(previous: Int, current: Int)>()
    let cancellable = publisher.sink { recorder.append($0) }

    subject.send(2)
    subject.send(3)
    cancellable.cancel()

    #expect(recorder.values.map { $0.previous } == [1, 1, 2])
    #expect(recorder.values.map { $0.current } == [1, 2, 3])
  }
}

private final class ValueRecorder<Value>: @unchecked Sendable {
  private(set) var values: [Value] = []

  func append(_ value: Value) {
    values.append(value)
  }
}