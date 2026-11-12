/// Connection state of the app with its peer devices (UI_SPEC §5.1).
///
/// The sync server itself ships in the sync phase; until it exists the app
/// runs in *local only* mode and the UI says so honestly instead of pretending
/// to be connected.
library;

enum SyncConnectionState {
  /// The user has not paired any device yet.
  notConfigured,

  /// A connection attempt is running.
  connecting,

  /// Paired and reachable.
  connected,

  /// The last attempt failed (network error, wrong code…).
  failed,

  /// The server could not be reached at all (not running, wrong address).
  serverUnavailable,
}

extension ConnectionStateLabel on SyncConnectionState {
  /// Arabic label — always shown as text next to the colour/icon so the state
  /// never depends on colour alone (UI_SPEC §3.8).
  String get label => switch (this) {
        SyncConnectionState.notConfigured => 'غير مقترن',
        SyncConnectionState.connecting => 'جارٍ الاتصال…',
        SyncConnectionState.connected => 'متصل',
        SyncConnectionState.failed => 'فشل الاتصال',
        SyncConnectionState.serverUnavailable => 'الخادم غير متاح',
      };

  bool get isBusy => this == SyncConnectionState.connecting;
  bool get isUsable => this == SyncConnectionState.connected;
}

/// Result of a connection test performed in the setup screen.
class ConnectionTestResult {
  const ConnectionTestResult({
    required this.state,
    this.message,
    this.serverAddress,
  });

  final SyncConnectionState state;
  final String? message;
  final String? serverAddress;
}

/// Abstraction over the pairing/transport layer.
///
/// The real implementation (HTTPS pairing, QR, token) belongs to the sync
/// phase; the interface exists so the UI can be built and tested now.
abstract class ConnectionService {
  /// Current state of the connection.
  SyncConnectionState get state;

  /// Tests a server address (and optional pairing code) — used by the setup
  /// screen and by "اختبار الاتصال" in the settings.
  Future<ConnectionTestResult> test({
    required String serverAddress,
    String? pairingCode,
  });

  /// Forgets the pairing information (settings screen).
  Future<void> reset();
}

/// Default implementation used until the sync transport exists: the app is
/// local-only, so a test always ends in "server unavailable" with an explicit
/// message instead of a fake success.
class LocalOnlyConnectionService implements ConnectionService {
  LocalOnlyConnectionService();

  @override
  SyncConnectionState get state => SyncConnectionState.serverUnavailable;

  @override
  Future<ConnectionTestResult> test({
    required String serverAddress,
    String? pairingCode,
  }) async {
    return ConnectionTestResult(
      state: SyncConnectionState.serverUnavailable,
      serverAddress: serverAddress,
      message: 'خادم المزامنة غير متاح في هذه النسخة بعد. '
          'البيانات محفوظة محليًا على هذا الجهاز، ويمكن ربط الأجهزة لاحقًا.',
    );
  }

  @override
  Future<void> reset() async {}
}
