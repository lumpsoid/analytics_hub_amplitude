import 'dart:async';
import 'dart:developer' as dev;

import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:amplitude_flutter/events/identify.dart';
import 'package:analytics_hub_amplitude/src/amplitude_config.dart';
import 'package:analytics_hub_amplitude/src/amplitude_revenue_mapper.dart';
import 'package:analytics_hub_core/analytics_hub_core.dart';

/// Production [AnalyticsProvider] backed by the Amplitude Flutter SDK.
///
/// ## Revenue tracking
///
/// Dispatch a [RevenueEvent] through the hub — this provider automatically
/// routes it to Amplitude's `revenue` API so it appears in the Revenue
/// dashboard rather than as a plain event.
///
/// ```dart
/// hub.track(RevenueEvent(
///  amount: 9.99,
///  currency: 'USD',
///  productId: 'pro_monthly',
/// ));
/// ```
class AmplitudeAnalyticsProvider implements AnalyticsProvider {
  AmplitudeAnalyticsProvider({required this.config});

  final AmplitudeProviderConfig config;

  late final Amplitude _client;
  bool _initialized = false;

  /// Initialises the Amplitude SDK.
  ///
  /// Called exactly once by [AnalyticsHub.init]. All [AsyncPropertySource]s
  /// have already been resolved and are available as enriched event properties
  /// by the time `track` is first called — no extra work needed here.
  @override
  Future<void> init(AnalyticsCoreConfig config) async {
    if (this.config.disabled) {
      _log('disabled — skipping init');
      return;
    }

    _client = Amplitude(
      Configuration(
        apiKey: this.config.apiKey,
        instanceName: this.config.instanceName,
        flushQueueSize: this.config.flushQueueSize,
        flushIntervalMillis: this.config.flushIntervalMillis,
      ),
    );

    await _client.isBuilt;

    _log(
      'init | instance=${this.config.instanceName} '
      'env=${config.environment.name}',
    );

    _initialized = true;
  }

  /// Tracks an event.
  ///
  /// [RevenueEvent]s are forwarded to `logRevenue`; all other events use
  /// `track`. By the time this is called the hub has already:
  ///  - checked consent
  ///  - merged global / super properties into `event.toProperties()`
  ///  - run PII scrubbing and deduplication middleware
  @override
  Future<void> track(AnalyticsEvent event) async {
    if (!_assertInitializedSync()) return;

    if (event is RevenueEvent) {
      await _trackRevenue(event);
    } else {
      await _trackEvent(event);
    }
  }

  @override
  Future<void> identify(
    String userId, {
    Map<String, Object> traits = const {},
  }) async {
    if (!_assertInitializedSync()) return;

    await _guard('identify', () async {
      await _client.setUserId(userId);

      _log('identify | userId=$userId traits=${traits.keys.toList()}');

      if (traits.isNotEmpty) {
        final identify = Identify();
        traits.forEach(identify.set);
        await _client.identify(identify);
      }
    });
  }

  /// Amplitude has no first-class `alias` API in the Flutter SDK.
  ///
  /// The standard approach is to store the previous anonymous ID in a
  /// reserved user property (`previous_id`) so the server-side merge can
  /// stitch pre-login events to the identified profile.
  @override
  Future<void> alias(String newId, String previousId) async {
    if (!_assertInitializedSync()) return;

    await _guard('alias', () async {
      _log('alias | $previousId → $newId');

      final identify = Identify()
        ..set('previous_id', previousId)
        ..set('canonical_id', newId);

      await _client.identify(identify);
    });
  }

  @override
  Future<void> reset() async {
    if (!_assertInitializedSync()) return;

    await _guard('reset', () async {
      _log('reset');
      await _client.reset();
    });
  }

  @override
  Future<void> flush() async {
    if (!_assertInitializedSync()) return;

    await _guard('flush', () async {
      _log('flush');
      await _client.flush();
    });
  }

  @override
  Future<void> dispose() async {
    if (!_initialized) return;

    await _guard('dispose', () async {
      _log('dispose — flushing before teardown');
      await _client.flush();
    });

    _initialized = false;
  }

  // Private helpers

  Future<void> _trackEvent(AnalyticsEvent event) =>
      _guard('track:${event.name}', () async {
        final properties = event.toProperties();

        _log(
          'track | ${event.name} @ ${event.timestamp.toIso8601String()}\n'
          '${_formatProps(properties)}',
        );

        await _client.track(
          BaseEvent(
            event.name,
            eventProperties: properties.isEmpty ? null : properties,
            // Preserve the original event timestamp so server-side ordering
            // is correct even when events are delivered from a queue.
            timestamp: event.timestamp.millisecondsSinceEpoch,
          ),
        );
      });

  Future<void> _trackRevenue(RevenueEvent event) =>
      _guard('track:revenue', () async {
        _log(
          'revenue | ${event.productId} '
          'amount=${event.amount} ${event.currency} qty=${event.quantity}',
        );

        final revenue = AmplitudeRevenueMapper.toAmplitudeRevenue(event);
        await _client.revenue(revenue);
      });

  /// Runs [fn] inside a try/catch.
  ///
  /// Returns a [Future] so callers that need to await (e.g. [flush]) can do
  /// so; fire-and-forget callers simply don't await the returned future.
  Future<void> _guard(String operation, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (error, stackTrace) {
      _logError('operation=$operation', error, stackTrace);

      if (config.throwOnError) {
        throw AmplitudeProviderException(
          'Amplitude operation "$operation" failed: $error',
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Returns `false` (and logs a warning) when called before [init].
  ///
  /// Using a bool return rather than throwing keeps [track] — a void,
  /// fire-and-forget method — safe to call without try/catch at the call site.
  bool _assertInitializedSync() {
    if (config.disabled) return false;
    if (!_initialized) {
      assert(
        false,
        'AmplitudeAnalyticsProvider.init() must be called before use.',
      );
      _logError(
        'called before init — call discarded',
        StateError('not initialized'),
        StackTrace.current,
      );
      return false;
    }
    return true;
  }

  void _log(String message) {
    if (!config.enableLogging) return;
    dev.log(message, name: 'Amplitude[${config.instanceName}]');
  }

  void _logError(String message, Object error, StackTrace stackTrace) {
    dev.log(
      message,
      name: 'Amplitude[${config.instanceName}]',
      error: error,
      stackTrace: stackTrace,
      level: 1000, // dart:developer SEVERE
    );
  }

  String _formatProps(Map<String, Object> props) {
    if (props.isEmpty) return ' (no properties)';
    return props.entries.map((e) => ' ${e.key}: ${e.value}').join('\n');
  }
}

/// Thrown by [AmplitudeAnalyticsProvider] when
/// [AmplitudeProviderConfig.throwOnError] is `true` and an SDK call fails.
class AmplitudeProviderException implements Exception {
  const AmplitudeProviderException(
    this.message, {
    required this.cause,
    required this.stackTrace,
  });

  final String message;
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() =>
      'AmplitudeProviderException: $message\nCaused by: $cause';
}
