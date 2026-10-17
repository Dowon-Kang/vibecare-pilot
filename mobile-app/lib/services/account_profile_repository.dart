import 'package:supabase_flutter/supabase_flutter.dart';

class AccountProfile {
  const AccountProfile({
    required this.age,
    required this.sex,
    required this.heightCm,
  });
  final int age;
  final String sex;
  final double heightCm;
  bool get valid =>
      age >= 18 &&
      age <= 100 &&
      ['female', 'male'].contains(sex) &&
      heightCm.isFinite &&
      heightCm >= 120 &&
      heightCm <= 220;
  factory AccountProfile.fromJson(Map<String, dynamic> row) {
    if (row['age'] is! int ||
        row['sex'] is! String ||
        row['height_cm'] is! num) {
      throw const FormatException('Invalid profile');
    }
    final profile = AccountProfile(
      age: row['age'] as int,
      sex: row['sex'] as String,
      heightCm: (row['height_cm'] as num).toDouble(),
    );
    if (!profile.valid) throw const FormatException('Invalid profile');
    return profile;
  }
}

abstract interface class AccountProfileRepository {
  Future<AccountProfile?> load();
  Future<AccountProfile> save(AccountProfile profile);
}

class SupabaseAccountProfileRepository implements AccountProfileRepository {
  const SupabaseAccountProfileRepository(this.client, this.owner);
  final SupabaseClient client;
  final String owner;
  void _checkOwner() {
    final user = client.auth.currentUser;
    if (user == null || user.id != owner || user.isAnonymous) {
      throw StateError('account changed');
    }
  }

  @override
  Future<AccountProfile?> load() async {
    _checkOwner();
    final row = await client
        .from('account_profiles')
        .select('user_id,age,sex,height_cm')
        .eq('user_id', owner)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    _checkOwner();
    if (row == null) return null;
    if (row['user_id'] != owner) throw const FormatException('Invalid owner');
    return AccountProfile.fromJson(row);
  }

  @override
  Future<AccountProfile> save(AccountProfile profile) async {
    _checkOwner();
    if (!profile.valid) throw const FormatException('Invalid profile');
    final row = await client
        .from('account_profiles')
        .upsert({
          'user_id': owner,
          'age': profile.age,
          'sex': profile.sex,
          'height_cm': profile.heightCm,
        })
        .select('user_id,age,sex,height_cm')
        .single()
        .timeout(const Duration(seconds: 15));
    _checkOwner();
    if (row['user_id'] != owner) throw const FormatException('Invalid owner');
    return AccountProfile.fromJson(row);
  }
}
