# ABUS Roadmap

ABUS (Asynchronous Business Logic Unification System) began as a unified solution for managing asynchronous interactions in Flutter applications with features such as optimistic updates, rollback handling, prioritization, and UI synchronization.

This roadmap outlines the planned growth of ABUS into a broader **interaction bus** capable of managing not only async operations but also user feedback, cross-application communication, and system-wide coordination.

---

## Phase 1: Core Improvements
- Expand documentation with real-world usage examples (e.g., social apps, forms, collaborative tools).
- Provide integration adapters for more state management systems (Riverpod, GetX, MobX).
- Improve test coverage and add stress tests for concurrency, rollback, and conflict scenarios.
- Enhance logging and developer tooling for tracing optimistic updates and rollbacks.

---

## Phase 2: Global Feedback System
- Implement a **SnackbarBus** to centrally manage snackbars across the entire app.
- Prevent overlapping or delayed snackbars by introducing a queue with ordering and priority.
- Support deduplication of identical feedback events.
- Extend the system to handle banners, and toasts as **FeedbackEvents**, ensuring consistent behavior across pages and navigations.

---

## Phase 3: Offline and Persistence Layer
- Add support for offline-first workflows by queueing operations while offline.
- Replay pending operations automatically when connectivity is restored.
- Provide simple conflict resolution strategies (last write wins, merge, manual resolution).
- Persist interaction history so that pending operations survive app restarts.

---

## Phase 4: Cross-Application Communication (Same Device)
- Provide APIs for inter-app communication using Android Intents, iOS App Links, and URL Schemes.
- Standardize these into ABUS events that look like normal operations within the system.
- Support local shared storage mechanisms (App Groups on iOS, Content Providers on Android) to exchange data between applications.
- Introduce security and permissions for defining which apps can send and receive which events.

---

## Phase 5: Cross-Application Channels (Multi-App Ecosystems)
- Define **channels** that applications can publish to and subscribe from.
- Enable scenarios where multiple apps form part of a single ecosystem (main app, companion app, lightweight extensions).
- Support both same-device and multi-device communication, using backends or peer-to-peer protocols (WebSocket, MQTT, WebRTC).
- Provide ordered, replayable, and rollback-aware event delivery across apps.

---

## Phase 6: Advanced System Integration
- Add a global retry manager for failed operations across multiple apps.
- Integrate with OS-level notifications for consistent cross-app and background feedback.
- Provide APIs for background services and tasks (uploads, downloads, synchronization) unified under ABUS.
- Add hooks for analytics, monitoring, and crash reporting to capture full lifecycle of interactions.

---

## Phase 7: Extensibility and Plugins
- Introduce middleware support to allow developers to inject custom logic into the ABUS pipeline (e.g., analytics, custom retry strategies, security checks).
- Provide a plugin mechanism for third-party developers to extend ABUS with new event types and handlers.
- Document best practices for creating reusable ABUS plugins and modules.

---

## Long-Term Vision
The long-term goal is for ABUS to become a **universal interaction bus for Flutter applications**:
- Intra-app: async operations, optimistic updates, rollbacks, feedback.
- Cross-app: communication and data exchange across applications.
- Cross-device: synchronization of events and state across multiple devices.

