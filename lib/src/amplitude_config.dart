import 'package:analytics_hub_core/analytics_hub_core.dart';

/// Amplitude-specific configuration.
///
/// Pass an instance to [AmplitudeAnalyticsProvider] at construction time.
///
/// ```dart
/// AmplitudeAnalyticsProvider(
///   config: AmplitudeProviderConfig(
///     apiKey: const String.fromEnvironment('AMPLITUDE_API_KEY'),
///     environment: Environment.prod,
///   ),
/// )
/// ```
class AmplitudeProviderConfig {
  const AmplitudeProviderConfig({
    required this.apiKey,
    this.instanceName = 'default',

    /// Maximum number of events batched before an automatic flush.
    this.flushQueueSize = 30,

    /// Automatic flush interval in milliseconds.
    this.flushIntervalMillis = 30000,

    /// Log every SDK call to [dart:developer]. Never enable in prod builds.
    this.enableLogging = false,

    /// Re-throw exceptions after logging. Useful in CI / tests.
    this.throwOnError = false,

    /// When `true`, the [AmplitudeAnalyticsProvider] is treated as a
    /// no-op. Useful to disable Amplitude in [Environment.dev] without
    /// removing it from the slot list.
    this.disabled = false,
  });

  final String apiKey;
  final String instanceName;
  final int flushQueueSize;
  final int flushIntervalMillis;
  final bool enableLogging;
  final bool throwOnError;
  final bool disabled;

  /// Convenience factory that applies sensible defaults per environment.
  factory AmplitudeProviderConfig.forEnvironment({
    required String apiKey,
    required Environment environment,
    String instanceName = 'default',
  }) {
    return AmplitudeProviderConfig(
      apiKey: apiKey,
      instanceName: instanceName,
      enableLogging: environment != Environment.prod,
      throwOnError: environment == Environment.dev,
      disabled: false,
    );
  }
}
