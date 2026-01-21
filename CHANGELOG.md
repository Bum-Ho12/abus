## 0.0.7
- **Documentation Overhaul**: Restructured README to feature Feedback System and Cross-App Communication as core components.
- **New Guides**: Added detailed "Consuming Feedback" guide with UI examples and "Storage Deep Dive" in DOCs.md.
- **Improved Examples**: Updated Quick Start to show unified initialization of Storage and Feedback.

## 0.0.6
- Updated README documentation to reflect recent changes and version bump.

## 0.0.5
- **Feedback System Reliability**: Significantly improved cross-app feedback stability by optimizing the underlying shared storage mechanism.
- **Performance Optimization**: Implemented "Smart Sync" in `AndroidSharedStorage` to detect actual content changes, eliminating redundant updates and reducing resource usage.
- **Concurrency Safety**: Added exclusive file locking for storage write operations to prevent race conditions during simultaneous cross-app communication.
- **Documentation**: Fixed rendering issues with flow diagrams and updated documentation with new storage optimization details.
- **Refactoring**: Minor code cleanup and modernization in storage constructors.

## 0.0.4

- Files formatted to adhere to dart conventions.
- Improved code documentations and library guides.
- Improvements in file documentations for easier and faster access.

## 0.0.3

- Added Support for class interactions, using the withPayload to pass classes.
- Improved code documentations and library guides.
- Robust feedback and debugging.

## 0.0.2

- Added proper `example/lib/main.dart` so pub.dev displays the example.
- Improved documentation and links.
- Prepared for first visible example-based release.

## 0.0.1

- Initial public release of the ABUS package.
- Supports optimistic interaction updates with rollback.
- Provides integration with BLoC and Provider.
- Includes mixins and a result tracking system.
