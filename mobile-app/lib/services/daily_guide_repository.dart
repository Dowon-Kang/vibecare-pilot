import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_guide.dart';

/// Fresh, account-scoped read. No model provider or client-supplied subject ID.
class SupabaseDailyGuideRepository {
  const SupabaseDailyGuideRepository(this.client);
  final SupabaseClient client;

  Future<List<ParticipantReading>> load() => loadOwnedGuideReadings(
    currentOwner: () => client.auth.currentUser?.id,
    fetch: () => client.rpc('daily_guide_context'),
  );
}

Future<List<ParticipantReading>> loadOwnedGuideReadings({
  required String? Function() currentOwner,
  required Future<dynamic> Function() fetch,
}) async {
  final owner = currentOwner();
  if (owner == null) throw StateError('authentication required');
  final result = await fetch().timeout(const Duration(seconds: 15));
  if (currentOwner() != owner) throw StateError('account changed');
  if (result is! List || result.length > 10) throw const FormatException();
  return [for (final row in result) parseGuideReading(row)];
}

ParticipantReading parseGuideReading(dynamic row) {
  if (row is! Map ||
      row['measurement_id'] is! String ||
      (row['measurement_id'] as String).isEmpty ||
      row['eligible'] is! bool ||
      row['measured_at'] is! String) {
    throw const FormatException();
  }
  for (final name in ['muscle_kg', 'weight_kg', 'body_fat_pct']) {
    if (row[name] is! num || !(row[name] as num).isFinite) {
      throw const FormatException();
    }
  }
  final group = row['comparison_key'];
  if (row['eligible'] == true &&
      (group is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(group))) {
    throw const FormatException();
  }
  return ParticipantReading(
    DateTime.parse(row['measured_at'] as String).toLocal(),
    (row['muscle_kg'] as num).toDouble(),
    (row['weight_kg'] as num).toDouble(),
    (row['body_fat_pct'] as num).toDouble(),
    recommendationEligible: row['eligible'] as bool,
    comparisonKey: row['eligible'] == true ? group as String : null,
  );
}
