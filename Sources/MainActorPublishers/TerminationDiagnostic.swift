import Combine
import SendableCombineLogging

@inline(never)
func _logTerminationDiagnostic<Failure: Error>(
  logWhenTerminated: Bool,
  finishedCode: SendableCombineInternalErrorCode,
  failureCode: SendableCombineInternalErrorCode,
  publisherName: String,
  completion: Subscribers.Completion<Failure>
) {
  guard logWhenTerminated else { return }
  switch completion {
  case .finished:
    _log(.warning, SendableCombineLogEntry(code: finishedCode,
                                           message: "The \(publisherName) upstream terminated with COMPLETION. The shared event stream is now permanently closed - no further events will be delivered."))
  case .failure(let error):
    _log(.warning, SendableCombineLogEntry(code: failureCode,
                                           message: "The \(publisherName) upstream terminated with error: \(error). The shared event stream is now permanently closed - no further events will be delivered."))
  }
}
