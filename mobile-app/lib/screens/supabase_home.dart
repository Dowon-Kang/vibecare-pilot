import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_input_validation.dart';
import '../services/participation_repository.dart';
import '../widgets/app_menu_button.dart';
import 'participant_shell.dart';
import '../services/booking_reminder.dart';
import 'sample_pilot_scope.dart';

class _MeasurementPoint {
  const _MeasurementPoint(this.date, this.weight, this.muscle, this.bodyFat);

  final DateTime date;
  final double weight;
  final double muscle;
  final double bodyFat;

  factory _MeasurementPoint.fromJson(Map<String, dynamic> row) =>
      _MeasurementPoint(
        DateTime.parse(row['measured_at'] as String).toLocal(),
        (row['weight_kg'] as num).toDouble(),
        (row['skeletal_muscle_mass_kg'] as num).toDouble(),
        (row['body_fat_pct'] as num).toDouble(),
      );
}

class _Announcement {
  const _Announcement(this.title, this.body);

  final String title;
  final String body;

  factory _Announcement.fromJson(Map<String, dynamic> row) =>
      _Announcement(row['title'] as String, row['body'] as String);
}

class SupabaseHome extends StatefulWidget {
  const SupabaseHome({super.key, this.client});

  final SupabaseClient? client;

  @override
  State<SupabaseHome> createState() => _SupabaseHomeState();
}

class _SupabaseHomeState extends State<SupabaseHome> {
  late final SupabaseClient _client = widget.client ?? Supabase.instance.client;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  GlobalKey<FormState> _authFormKey = GlobalKey<FormState>();
  StreamSubscription<AuthState>? _authSubscription;
  User? _user;
  List<_MeasurementPoint> _measurements = [];
  List<_Announcement> _announcements = [];
  bool _busy = false;
  bool _signUpMode = false;
  bool _messageIsError = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _user = _client.auth.currentUser;
    _authSubscription = _client.auth.onAuthStateChange.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          final nextUser = event.session?.user;
          if (nextUser?.id != _user?.id) {
            final oldId = _user?.id;
            if (oldId != null) {
              unawaited(
                const BookingReminder()
                    .deactivate('account:$oldId')
                    .catchError((Object _) {}),
              );
            }
            _measurements = [];
            _announcements = [];
            _message = null;
          }
          _user = nextUser;
          if (_user == null) {
            _measurements = [];
            _announcements = [];
          }
        });
        if (_user != null) unawaited(_reload());
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted) return;
        final oldId = _user?.id;
        if (oldId != null) {
          unawaited(
            const BookingReminder()
                .deactivate('account:$oldId')
                .catchError((Object _) {}),
          );
        }
        setState(() {
          _user = null;
          _measurements = [];
          _announcements = [];
          _messageIsError = true;
          _message = '계정 연결 상태를 확인할 수 없습니다. 다시 로그인해 주세요.';
        });
      },
    );
    if (_user != null) unawaited(_reload());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_busy || !(_authFormKey.currentState?.validate() ?? false)) return;
    final signUp = _signUpMode;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final email = _email.text.trim();
      final password = _password.text;
      if (signUp) {
        final result = await _client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: Uri.base.toString(),
        );
        if (result.user == null) {
          throw StateError('계정 생성 응답이 비어 있습니다. 다시 시도해 주세요.');
        }
        if (mounted && result.session == null) {
          setState(() {
            _signUpMode = false;
            _messageIsError = false;
            _message = '가입 요청이 접수됐습니다. 받은편지함이나 스팸함의 확인 링크를 누른 뒤 로그인해 주세요.';
          });
        }
      } else {
        await _client.auth.signInWithPassword(email: email, password: password);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _messageIsError = true;
          _message = _authError(error);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('rate limit')) {
        return '이메일 전송 횟수 제한에 걸렸습니다. 잠시 후 다시 시도해 주세요.';
      }
      if (message.contains('email address not authorized')) {
        return '이 주소로 확인 메일을 보낼 수 없습니다. 관리자에게 이메일 발신 설정을 요청해 주세요.';
      }
      if (message.contains('already registered')) {
        return '이미 가입된 이메일입니다. 로그인해 주세요.';
      }
      if (message.contains('signup') && message.contains('disabled')) {
        return '현재 계정 생성이 비활성화되어 있습니다. 관리자에게 문의해 주세요.';
      }
      return error.message;
    }
    if (error is StateError) return error.message;
    return '연결을 확인한 뒤 다시 시도해 주세요.';
  }

  void _toggleAuthMode() {
    setState(() {
      _signUpMode = !_signUpMode;
      _message = null;
      _confirmPassword.clear();
      _authFormKey = GlobalKey<FormState>();
    });
  }

  Future<void> _reload() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) return;
    try {
      final results = await Future.wait<dynamic>([
        _client
            .from('vibecare_measurements')
            .select(
              'measured_at, weight_kg, skeletal_muscle_mass_kg, body_fat_pct',
            )
            .order('measured_at', ascending: false),
        _client
            .from('announcements')
            .select('title, body')
            .order('published_at', ascending: false)
            .limit(5),
      ]);
      if (!mounted || _client.auth.currentUser?.id != id) return;
      setState(() {
        _measurements = [
          for (final row in results[0] as List<dynamic>)
            _MeasurementPoint.fromJson(row as Map<String, dynamic>),
        ];
        _announcements = [
          for (final row in results[1] as List<dynamic>)
            _Announcement.fromJson(row as Map<String, dynamic>),
        ];
        _message = null;
      });
    } catch (_) {
      if (mounted && _client.auth.currentUser?.id == id) {
        setState(() => _message = 'Supabase 데이터를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    }
  }

  void _openDemo() {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const SamplePilotScope()));
  }

  @override
  Widget build(BuildContext context) => _user == null ? _login() : _dashboard();

  Widget _login() => Scaffold(
    appBar: AppBar(
      title: const Text('VibeCare'),
      actions: [
        AppMenuButton(
          actions: [
            AppMenuAction(
              label: _signUpMode ? '로그인' : '새 계정 만들기',
              icon: _signUpMode ? Icons.login : Icons.person_add_outlined,
              onSelected: _toggleAuthMode,
              enabled: !_busy,
            ),
            AppMenuAction(
              label: '샘플 시연',
              icon: Icons.play_arrow,
              onSelected: _openDemo,
            ),
          ],
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _signUpMode ? '새 계정 만들기' : '참여 기록에 로그인',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _signUpMode
                    ? '이메일과 비밀번호를 입력해 가입하세요. 확인 메일 인증 후 로그인할 수 있습니다.'
                    : 'Supabase 계정으로 예약, 출석, 연결된 측정 기록을 확인합니다.',
              ),
              const SizedBox(height: 24),
              Form(
                key: _authFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: validateAuthEmail,
                      decoration: const InputDecoration(labelText: '이메일'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      validator: validateAuthPassword,
                      onFieldSubmitted: (_) {
                        if (!_signUpMode) _authenticate();
                      },
                      decoration: const InputDecoration(
                        labelText: '비밀번호 · 6자 이상',
                      ),
                    ),
                    if (_signUpMode) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: true,
                        validator: (value) =>
                            validatePasswordConfirmation(_password.text, value),
                        onFieldSubmitted: (_) => _authenticate(),
                        decoration: const InputDecoration(labelText: '비밀번호 확인'),
                      ),
                    ],
                  ],
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _messageIsError
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _busy ? null : _authenticate,
                child: Text(
                  _busy
                      ? '처리 중...'
                      : _signUpMode
                      ? '가입 요청 보내기'
                      : '로그인',
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _toggleAuthMode,
                child: Text(_signUpMode ? '로그인으로 돌아가기' : '새 계정 만들기'),
              ),
              const SizedBox(height: 16),
              const Text('로그인 전에도 합성 데이터로 추천 매핑 화면을 볼 수 있습니다.'),
              OutlinedButton(
                onPressed: _openDemo,
                child: const Text('샘플 시연 화면 보기'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _dashboard() {
    final id = _user!.id;
    return ParticipantShell(
      key: ValueKey('account:$id'),
      owner: 'account:$id',
      participantId: id,
      sample: false,
      repository: SupabaseParticipationRepository(_client),
      identity: _user!.email ?? '참여자',
      canAccess: () => _client.auth.currentUser?.id == id,
      accessChanges: _client.auth.onAuthStateChange.map(
        (event) => event.session?.user.id == id,
      ),
      readings: [
        for (final m in _measurements)
          ParticipantReading(m.date, m.muscle, m.weight, m.bodyFat),
      ],
      notices: [for (final a in _announcements) (title: a.title, body: a.body)],
      onStart: _openDemo,
      onRefresh: _reload,
      dataError: _message,
      onSignOut: () => _client.auth.signOut(),
    );
  }
}
