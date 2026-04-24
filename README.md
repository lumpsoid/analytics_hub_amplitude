# analytics_hub_amplitude

Amplitude analytics provider for the Analytics Hub.

## Features

- Full implementation of `AnalyticsProvider` interface
- Automatic revenue event routing to Amplitude's revenue API
- Configurable logging and error handling
- Environment-aware defaults
- Type-safe event tracking with DTOs
- Comprehensive error isolation with optional error throwing

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  analytics_hub_core: ^0.1.0
  analytics_hub_amplitude: ^0.1.0
```

## Quick Start

```dart
import 'package:analytics_hub/analytics_hub.dart';
import 'package:analytics_hub_amplitude/analytics_hub_amplitude.dart';

void main() async {
  final hub = AnalyticsHub(
    providers: [
      AmplitudeAnalyticsProvider(
        config: AmplitudeProviderConfig(
          apiKey: const String.fromEnvironment('AMPLITUDE_API_KEY'),
          environment: Environment.prod,
        ),
      ),
    ],
  );

  await hub.init(
    AnalyticsCoreConfig(
      environment: Environment.prod,
      // ... other core config
    ),
  );

  // Track standard event
  await hub.track(AnalyticsEvent(
    name: 'button_clicked',
    properties: {'button_id': 'signup'},
  ));

  // Track revenue event (auto-routed to revenue API)
  await hub.track(RevenueEvent(
    amount: 9.99,
    currency: 'USD',
    productId: 'pro_monthly',
    quantity: 1,
  ));
}
```

## Configuration

### `AmplitudeProviderConfig`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `apiKey` | `String` | **required** | Your Amplitude project API key |
| `instanceName` | `String` | `'default'` | Named instance for multi-instance setups |
| `flushQueueSize` | `int` | `30` | Events to batch before auto-flush |
| `flushIntervalMillis` | `int` | `30000` | Auto-flush interval (ms) |
| `enableLogging` | `bool` | `false` | Log SDK calls via `dart:developer` |
| `throwOnError` | `bool` | `false` | Rethrow exceptions (useful for CI/testing) |
| `disabled` | `bool` | `false` | Disable provider without removing from slot |

### Environment-aware factory

```dart
AmplitudeProviderConfig.forEnvironment(
  apiKey: 'YOUR_KEY',
  environment: Environment.dev, // or .staging, .prod
);
```

**Default behaviors per environment:**
- `dev`: `enableLogging: true`, `throwOnError: true`
- `staging`: `enableLogging: true`, `throwOnError: false`
- `prod`: `enableLogging: false`, `throwOnError: false`

## Event Handling

### Standard Events
All non-revenue events use Amplitude's `track()` API:

```dart
await hub.track(AnalyticsEvent(
  name: 'screen_viewed',
  properties: {'screen': 'home'},
));
```

### Revenue Events
Automatic routing to Amplitude's revenue dashboard:

```dart
await hub.track(RevenueEvent(
  amount: 19.99,
  currency: 'EUR',
  productId: 'premium_yearly',
  quantity: 2,
  properties: {'promo_code': 'SUMMER21'},
));
```

## User Identification

### Set User ID
```dart
await hub.identify('user_123', traits: {
  'email': 'user@example.com',
  'plan': 'premium',
});
```

### Alias (Anonymous → Known)
```dart
await hub.alias('user_123', 'anon_456');
```
*Uses Amplitude's `identify()` with `previous_id`/`canonical_id` properties*

## Lifecycle Management

```dart
// Flush pending events immediately
await hub.flush();

// Reset user context (logout)
await hub.reset();

// Cleanup on app exit
await hub.dispose();
```

## Error Handling

By default, all Amplitude SDK errors are **caught and logged** without disrupting your app. To propagate errors:

```dart
AmplitudeProviderConfig(
  apiKey: 'YOUR_KEY',
  throwOnError: true, // Rethrow exceptions
);
```

Custom exception thrown:
```dart
try {
  await hub.track(event);
} on AmplitudeProviderException catch (e) {
  print('Amplitude failed: ${e.message}');
  print('Cause: ${e.cause}');
}
```

## Development Tips

### Enable Debug Logging
```dart
AmplitudeProviderConfig(
  apiKey: 'YOUR_KEY',
  enableLogging: true, // Logs to dart:developer
);
```
View logs with:
```bash
flutter logs --filter=Amplitude
```

### Testing
```dart
// Mock provider for tests
final mockHub = AnalyticsHub(providers: [
  MockAnalyticsProvider(), // From analytics_hub_core test utils
]);
```

## Platform Support

- iOS (via `amplitude_flutter`)
- Android (via `amplitude_flutter`)
- Web (via `amplitude_flutter`)

## Limitations

1. **No alias() in Flutter SDK**: Workaround uses `identify()` with `previous_id` property
2. **Revenue only**: Non-revenue monetary events must use standard tracking
3. **No session management**: Session handling is internal to Amplitude SDK

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for changes
4. Run `flutter test`
5. Submit a pull request

## License

MIT License - See LICENSE file for details.
