import 'package:amplitude_flutter/events/revenue.dart';
import 'package:analytics_hub_core/analytics_hub_core.dart';

/// Maps a [RevenueEvent] to Amplitude's [Revenue] model.
///
/// Kept in its own file so the mapping logic is independently testable.
abstract final class AmplitudeRevenueMapper {
  /// Returns a configured [Revenue] object ready to pass to
  /// `Amplitude.logRevenue`.
  static Revenue toAmplitudeRevenue(RevenueEvent event) {
    final revenue = Revenue()
      ..price = event.amount
      ..quantity = event.quantity
      ..productId = event.productId
      ..revenueCurrency = event.currency
      ..properties = event.toProperties();

    return revenue;
  }
}
