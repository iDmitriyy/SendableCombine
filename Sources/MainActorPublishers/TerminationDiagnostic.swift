import Combine
import SendableCombineLogging

@inline(never)
func _logTerminationDiagnostic<Failure: Error>(
  logWhenTerminated: Bool,
  publisherName: String,
  completion: Subscribers.Completion<Failure>
) {
  guard logWhenTerminated else { return }
  
  let prefix = "The \(publisherName) " + "upstream terminated with "
  let suffix = "The shared event stream is now permanently closed – no further events will be delivered."
  
  let message: String
  switch completion {
  case .finished:
    message = prefix + "COMPLETION. " + suffix
    _log(.warning, SendableCombineLogEntry(code: .upstreamTerminatedWithCompletion,
                                           message: message))
  case .failure(let error):
    message = prefix + "error: \(error). " + suffix
    _log(.warning, SendableCombineLogEntry(code: .upstreamTerminatedWithFailure, message: message))
  }
}
