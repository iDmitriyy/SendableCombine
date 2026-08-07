# SendablePublishers

**Combine, ready for Swift 6 strict concurrency.**

A thin `Sendable` layer over Combine. It gives publishers an honest `Sendable` type, makes every operator closure `@Sendable`, and turns concurrency violations into compile errors – without changing how Combine feels to write.

Built with Swift 6 and the Swift 6 language mode. Wraps Combine. Reimplements nothing.

[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-orange)](https://swift.org) [![Platforms](https://img.shields.io/badge/iOS_15%2B-macOS_12%2B_tvOS_15%2B_watchOS_9%2B_visionOS_1-blue)](https://developer.apple.com/documentation/combine) [![SPM](https://img.shields.io/badge/SPM-Compatible-brightgreen)](#installation)

---

## Highlights

- **`SendablePublisher<Output, Failure>`** – a real, `Sendable` type for your signatures.
- **`SendableShell<Upstream>`** – an opaque wrapper that preserves the upstream type. No erasure, no runtime cost.
- **`@Sendable` everywhere** – every operator takes a `@Sendable` closure, so the compiler checks your chains instead of you.
- **Subjects become `Sendable`** – through a retroactive conformance that Combine's own thread-safety justifies.
- **Zero machinery, ~68 KB in release** – runtime behavior is Combine's. The whole library is a thin overlay; there is no custom subscription code to get wrong.
- **Actively developed** – `Driver` / `Signal` traits, `CancellationBag`, and AsyncAlgorithms interop are on the roadmap; see [Future Directions](#future-directions).

## The Problem

Under the Swift 6 language mode, Combine types are not `Sendable`. `Publisher`, `AnyPublisher`, `PassthroughSubject` – none of them are.

That means this won't compile:

```swift
// Swift 6, strict concurrency: does not compile.
import Combine

let subject = PassthroughSubject<Int, Never>()

Task { @MainActor in
  subject.send(1) // non-Sendable type captured in a @Sendable closure
}
```

The workarounds all cost something.

- `@preconcurrency import Combine` disables the diagnostics – project-wide. You lose the exact checks you turned on.
- `AsyncStream` sidesteps the issue, but throws away Combine's operators and backpressure model.
- Hand-rolled `@unchecked Sendable` wrappers – the same wrapper, re-written in every project that hits this.

SendablePublishers writes that wrapper once. Then the compiler works with you instead of against you.

## The Solution

The library does three things. Each is small; together they close the gap.

First, a typealias you can actually write in interfaces:

```swift
public typealias SendablePublisher<Output: Sendable, Failure> =
  Publisher<Output, Failure> & Sendable
```

Second, a concrete wrapper, `SendableShell<Upstream>`. A thin `@unchecked Sendable` struct that forwards `receive(subscriber:)` to the wrapped publisher and keeps the concrete type intact. No erasure, no overhead – just a `Sendable` overlay around a pipeline.

Third, a retroactive conformance for the two subjects you already use:

```swift
extension PassthroughSubject: @retroactive @unchecked Sendable where Output: Sendable {}
extension CurrentValueSubject: @retroactive @unchecked Sendable where Output: Sendable {}
```

The same code that failed above compiles after a single import:

```swift
import Combine
import SendablePublishers

let subject = PassthroughSubject<Int, Never>() // now Sendable
let events = subject.asSendablePublisher()      // SendableShell<...>, also Sendable

Task { @MainActor in
  subject.send(1)
}
```

## Extensible by design

The library is not closed off. If your project needs a case it does not cover, there is no reason to fork – the SPI is the extension point, and it is available to everyone.

- Wrap a publisher you can prove is thread-safe with the SPI initializer `unverified_SendablePublisher`. The "unverified" is literal: the compiler can't check it, so you take responsibility for its safety – only use it when you can explain why the publisher is safe.
- Reach the concrete upstream through `_upstream` when a tool needs the real type.
- Add your own operators with a plain extension, in your own module.

```swift
@_spi(ExtensionsUnsafeAPI) import SendablePublishers

// Wrap a custom publisher after proving it is thread-safe.
let wrapped = SendableShell(unverified_SendablePublisher: myPublisher)

// Add an operator of your own to the wrapper.
extension SendableShell {
  func toggle() -> SendableShell<Publishers.Map<Upstream, Bool>> {
    let toggled = _upstream.map { !$0 }
    return SendableShell<Publishers.Map<Upstream, Bool>>(unverified_SendablePublisher: toggled)
  }
}
```

## Future Directions

The `Sendable` layer is stable and usable as-is. What's in progress:

**`Driver` / `Signal` traits.** RxSwift-inspired `Sendable` hot streams whose `sink` always delivers on the main thread, with `drive(receiveValue:)` (replays the latest value on subscribe) and `emit(receiveValue:)` (no replay) – both closures `@MainActor`. This closes the one gap Sendability alone can't: a `send()` from any thread can no longer reach `@Published` off the main thread. Semantics – replay, zero-subscriber behavior – may adjust before release.

**`CancellationBag`.** A `~Copyable`, `Sendable` replacement for `Set<AnyCancellable>`. A class owns the bag; you `insert` an `AnyCancellable` or `any Cancellable` once, from any thread, and never manage it again. As a stored property, the bag lives and dies with its owner – when the owner deinits, the bag cancels everything it holds. No per-subscription bookkeeping; the owner's lifetime *is* the cancellation scope. A `Sendable` conformance on `AnyCancellable` alone would only satisfy the compiler; it wouldn't give you this.

```swift
@_staticExclusiveOnly
public struct CancellationBag: ~Copyable, Sendable {
  public func insert(_ cancellableObject: AnyCancellable)
  public func insert(_ cancellable: any Cancellable)
}
```

**AsyncAlgorithms interop.** A Sendable-clean bridge to [swift-async-algorithms](https://github.com/apple/swift-async-algorithms): feed a `SendablePublisher`'s output into its channels and buffers, and consume async sequences as `Sendable` publishers – so Combine's operators and AsyncAlgorithms' algorithms compose instead of competing.

**OpenCombine Integration.** 

The operator surface continues to track Combine's.

Considered, not committed: published build-time and binary-size benchmarks.

Feedback and contributions welcome.

## Quick Start

Wire a view model to a service. The publisher crosses an actor boundary; nothing blinks.

```swift
import Foundation
import SendablePublishers

struct Coordinates: Sendable, Equatable {
  let latitude: Double
  let longitude: Double
}

// A service owns the subject; callers receive a Sendable view of it.
final class LocationService {
  let coordinates: SendableShell<PassthroughSubject<Coordinates, Never>>

  init() {
    let subject = PassthroughSubject<Coordinates, Never>()
    coordinates = subject.asSendablePublisher()
  }
}
```

```swift
import Combine
import Foundation
import SendablePublishers

@MainActor
final class MapViewModel {
  var statusText = ""
  var cancellables = Set<AnyCancellable>()

  init(locationService: LocationService) {
    locationService.coordinates
      .filter { $0.latitude != 0 }
      .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
      .map { "\($0.latitude), \($0.longitude)" }
      .assign(to: \.statusText, on: self)   // Failure == Never, so assign is allowed
      .store(in: &cancellables)
  }
}
```

`LocationService` is a plain class, `MapViewModel` is actor-isolated. The publisher crosses that line because it is `Sendable`. Every closure above is `@Sendable`, and the compiler enforces it.

## Design

**Why a wrapper and not a rewrite.** The hard part of a reactive stream is the engine: threading, backpressure, cancellation. Combine already does this at Apple's performance level. This library puts a concurrency contract on top of that engine; it does not rebuild it. The footprint reflects that – the whole library compiles to roughly 68 KB in release, mostly protocol conformances and forwarding thunks. That is the price of a thin wrapping, and this is the point.

**Why `@unchecked Sendable`.** Swift cannot inspect Combine's internal locks, so the conformance is asserted rather than proven. This is a statement of trust in Apple's implementation, not an escape hatch from a problem. The wrapper adds nothing mutable, so whatever is safe inside Combine stays safe here.

**Why retroactive conformance is honest.** `PassthroughSubject` and `CurrentValueSubject` rely on thread-safe implementations; marking them `Sendable` where `Output: Sendable` states what is already true. The `@retroactive` keyword makes the intent explicit. If Apple formalizes these conformances, the two lines are simply deleted.

**How it compares.** The three common routes, at a glance:

| | `@preconcurrency import` | `AsyncStream` | SendablePublishers |
|---|---|---|---|
| Compile-time checks | off | none for streams | strict `@Sendable` |
| Combine operators | yes | no, rebuilt | yes |
| Sendable boundary type | none | `AsyncStream` | `SendablePublisher` |
| New mental model | no | yes (async/await) | no |

`@preconcurrency` turns the checks off for the whole module. SendablePublishers turns them on for every operator closure – a mistake becomes a compile error instead of a data race you debug at 2 a.m.

Nor is this a replacement for `AsyncSequence`. When you consume values sequentially with `for await`, a stream is the right tool. Different jobs.

## What you give up

Honest costs, stated plainly.

- Concrete types are preserved, so long chains produce long type names. Erase with `AnySendablePublisher` when that matters.
- The retroactive conformance is the library's only reach into Apple types. It is explicit, and it disappears if Apple ships its own.

## Requirements

- Swift 6.x / Xcode 16+, Swift 6 language mode, swift-tools 6.3.
- iOS 15+, macOS 12+, tvOS 15+, watchOS 9+, visionOS 1+, Mac Catalyst 15+.

## Patterns

### Hiding the pipeline

Preserved types are great until a stored property has to spell out a five-stage chain. Then erase:

```swift
let stream: AnySendablePublisher<String, Never> = queries
  .map { $0.trimmingCharacters(in: .whitespaces) }
  .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
  .share()
  .eraseToAnyPublisher()
```

There are two ways to hide a pipeline, and they answer different needs.

**`eraseToAnyPublisher() -> AnySendablePublisher`.** The named, type-erased container. Every pipeline erased to `AnySendablePublisher` becomes the same type, so it fits stored properties, arrays, and function parameters. Use it when the erased type has to be a real name – a property declaration, a collection, or a public contract between modules. It costs a small boxing layer.

**`eraseToOpaque() -> some SendablePublisher<Output, Failure>`.** Zero-cost hiding. It returns the pipeline under an opaque type – the caller can't see the concrete type, but there is no boxing. The catch: the type stays fixed and unnamed, so it can't be mixed with other erased types, and its uses in stored properties are limited.

Good fits for `eraseToOpaque()`:

- **Generic functions** – a helper that builds a pipeline and returns `some SendablePublisher<Output, Failure>`: the concrete type is derived from the generic parameters, and callers never have to spell it out.
- **API boundaries** – the public signature hides the pipeline, so you can change the operators inside without breaking callers.
- **Hot paths** – when the type only needs hiding, not erasing, there is no boxing allocation.

One caveat shared by both: after hiding, the value is a `Publisher & Sendable` you can subscribe to (`sink`, `assign`).

### Creating

```swift
let one: SendableShell<Just<Int>> = .just(1)
let empty: SendableShell<Empty<Int, Never>> = .empty()
let failure: SendableShell<Fail<Int, URLError>> = .fail(.init(.timedOut))
let ticks: SendableShell<Timer.TimerPublisher> = .timer(interval: 1, runLoop: .main)
let numbers: SendableShell<Publishers.Sequence<[Int], Never>> = .sequence([1, 2, 3])
```

### Transforming

```swift
let queries = searches
  .map { $0.lowercased() }
  .filter { !$0.isEmpty }
  .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
  .removeDuplicates()
```

### Combining

```swift
// combineLatest fires once every stream has produced, then on each change –
// the classic form-validation shape.
let isValid = username.combineLatest(password) { user, pass in
  user.count >= 3 && pass.count >= 8
}

let merged = liveFeed
  .merge(with: cachedFeed)
  .share()
```

### Handling errors

```swift
let loaded = network
  .retry(3)                                               // transient failures
  .catch { _ in SendableShell<Just<[Post]>>.just([]) } // then fall back

let saved = form
  .timeout(.seconds(5), scheduler: DispatchQueue.main) { URLError(.timedOut) }
  .catch { error in SendableShell<Just<Data>>.just(Data()) }
```

## Operators

Every operator wraps its Combine counterpart and returns `SendableShell`, so chains stay `Sendable` end to end. Closures are `@Sendable` unless marked otherwise.

| Group | Operators |
|---|---|
| Creation | `just`, `empty`, `fail`, `deferred`, `sequence`, `timer`, `asSendablePublisher()` on subjects |
| Transforming | `map`, `tryMap`, `compactMap`, `tryCompactMap`, `flatMap(maxPublishers:_:)`, `switchToLatest` |
| Combining | `merge(with:)` (2–8, plus variadic), `combineLatest(_:…:transform:)` (2–4), `zip(_:…:transform:)` (2–4), `prepend`, `append` |
| Error handling | `catch`, `tryCatch`, `retry`, `replaceError`, `replaceEmpty`, `assertNoFailure`, `setFailureType` |
| Filtering | `filter`, `tryFilter`, `removeDuplicates`, `ignoreOutput`, `prefix`, `prefix(while:)`, `prefix(untilOutputFrom:)`, `dropFirst`, `drop(while:)`, `drop(untilOutputFrom:)` |
| Time | `delay`, `debounce`, `throttle`, `timeout`, `measureInterval` |
| Scheduling | `receive(on:)`, `subscribe(on:)` |
| Accumulation | `scan`, `tryScan`, `reduce`, `tryReduce` |
| Buffering | `buffer`, `collect()`, `collect(_:)`, `collect(_ strategy:)` |
| Sequence & matching | `count`, `min`, `max`, `first`, `first(where:)`, `last`, `last(where:)`, `output(at:)`, `output(in:)`, `allSatisfy`, `contains`, `contains(where:)` |
| Sharing | `share`, `multicast(createSubject:)`, `multicast(subject:)`, `makeConnectable` |
| Side effects | `handleEvents`, `print`, `sink` (`@Sendable` closures), `assign(to:on:)` |

## Installation

Swift Package Manager is the only integration step.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "YourApp",
  dependencies: [
    .package(url: "https://github.com/iDmitriyy/SendablePublishers.git", branch: "main"),
  ],
  targets: [
    .target(name: "YourApp", dependencies: ["SendablePublishers"]),
  ]
)
```

Or in Xcode: **File → Add Package Dependencies**, paste the URL, add it to your target. One import later you're done.

```swift
import SendablePublishers
```

## Documentation

- [Combine](https://developer.apple.com/documentation/combine) – the framework this wraps; its types and semantics are your source of truth.
- [Swift Concurrency](https://developer.apple.com/documentation/swift/concurrency) – actors, `@Sendable`, and why Swift 6 tightened the rules.
- [Sendable](https://developer.apple.com/documentation/swift/sendable) – the protocol this library makes Combine types conform to.
