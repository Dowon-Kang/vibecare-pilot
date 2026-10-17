import 'dart:async';
import 'package:flutter/material.dart';
import '../services/account_profile_repository.dart';

/// Account-owned profile, separate from historical measurement snapshots.
class AccountProfileCard extends StatefulWidget {
  const AccountProfileCard({
    super.key,
    required this.repository,
    required this.canAccess,
    this.accessChanges,
  });
  final AccountProfileRepository repository;
  final bool Function() canAccess;
  final Stream<bool>? accessChanges;
  @override
  State<AccountProfileCard> createState() => _AccountProfileCardState();
}

class _AccountProfileCardState extends State<AccountProfileCard> {
  final _form = GlobalKey<FormState>();
  final _age = TextEditingController(), _height = TextEditingController();
  AccountProfile? _saved;
  String? _sex, _error, _message;
  bool _loading = true, _saving = false, _editing = false, _locked = false;
  int _generation = 0;
  StreamSubscription<bool>? _access;
  bool get _allowed => !_locked && widget.canAccess();
  @override
  void initState() {
    super.initState();
    _access = widget.accessChanges?.listen((value) {
      if (!value) _lock();
    }, onError: (Object e, StackTrace s) => _lock());
    _load();
  }

  void _lock() {
    if (!mounted) return;
    ++_generation;
    _age.clear();
    _height.clear();
    setState(() {
      _locked = true;
      _saved = null;
      _sex = null;
    });
  }

  void _fill(AccountProfile? value) {
    _age.text = value?.age.toString() ?? '';
    _height.text = value?.heightCm.toString() ?? '';
    _sex = value?.sex;
  }

  Future<void> _load() async {
    if (!_allowed) {
      _lock();
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.repository.load();
      if (!mounted || generation != _generation || !_allowed) return;
      setState(() {
        _saved = value;
        _fill(value);
        _editing = value == null;
      });
    } catch (_) {
      if (mounted && generation == _generation && _allowed) {
        setState(() => _error = '프로필을 불러오지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted && generation == _generation && _allowed) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving || !_allowed || !(_form.currentState?.validate() ?? false)) {
      return;
    }
    final value = AccountProfile(
      age: int.parse(_age.text.trim()),
      sex: _sex!,
      heightCm: double.parse(_height.text.trim()),
    );
    final generation = ++_generation;
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final saved = await widget.repository.save(value);
      if (!mounted || generation != _generation || !_allowed) return;
      setState(() {
        _saved = saved;
        _fill(saved);
        _editing = false;
        _message = '프로필을 저장했어요. 다음 로그인에도 자동으로 불러와요.';
      });
    } catch (_) {
      if (mounted && generation == _generation && _allowed) {
        setState(() => _error = '저장하지 못했어요. 입력한 정보를 확인하고 다시 저장해 주세요.');
      }
    } finally {
      if (mounted && generation == _generation && _allowed) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    _access?.cancel();
    _age.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const Text('계정이 변경됐습니다. 다시 로그인해 주세요.');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('기본 프로필', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null && !_editing) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('프로필 다시 불러오기')),
            ] else ...[
              if (_saved != null)
                Text(
                  '${_saved!.age}세 · ${_saved!.sex == 'female' ? '여성' : '남성'} · ${_saved!.heightCm.toStringAsFixed(1)}cm',
                ),
              if (!_editing)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _fill(_saved);
                    _editing = true;
                    _message = null;
                  }),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('프로필 수정'),
                ),
              if (_editing) ...[
                if (_saved == null) const Text('처음 한 번만 입력하면 다음 로그인에도 불러와요.'),
                const SizedBox(height: 12),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        key: const ValueKey('account-profile-age'),
                        controller: _age,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '나이',
                          suffixText: '세',
                        ),
                        validator: (s) {
                          final v = int.tryParse(s?.trim() ?? '');
                          return v == null || v < 18 || v > 100
                              ? '18~100세 사이로 입력해 주세요.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey('account-profile-sex:$_sex'),
                        initialValue: _sex,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '성별'),
                        items: const [
                          DropdownMenuItem(value: 'female', child: Text('여성')),
                          DropdownMenuItem(value: 'male', child: Text('남성')),
                        ],
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _sex = v),
                        validator: (s) => s == null ? '성별을 선택해 주세요.' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('account-profile-height'),
                        controller: _height,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '키',
                          suffixText: 'cm',
                        ),
                        validator: (s) {
                          final v = double.tryParse(s?.trim() ?? '');
                          return v == null || !v.isFinite || v < 120 || v > 220
                              ? '120~220cm 사이로 입력해 주세요.'
                              : null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? '저장 중…' : '프로필 저장'),
                ),
                if (_saved != null)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            _fill(_saved);
                            _editing = false;
                            _error = null;
                          }),
                    child: const Text('수정 취소'),
                  ),
              ],
              if (_message != null)
                Semantics(liveRegion: true, child: Text(_message!)),
            ],
          ],
        ),
      ),
    );
  }
}
