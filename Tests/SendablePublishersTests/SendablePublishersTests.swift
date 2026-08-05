import Testing
@testable import SendablePublishers

@Test func example() async throws {
  let subject = CurrentValueSubject<Int, Never>(7)

  let anySendablePublisher = subject.asSendablePublisher()
    .map { String($0) }
    .eraseToAnyPublisher()

  await Task(priority: .high) {
    var bag = Set<AnyCancellable>()

    print(anySendablePublisher)

    anySendablePublisher.sink(receiveValue: { print("receiveValue: ", $0) })
      .store(in: &bag)
  }.value
  
  print(subject.asSendablePublisher().eraseToOpaque())
  
  print(subject.eraseToAnyPublisher())
}
