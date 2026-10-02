String? validateAuthEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return '이메일을 입력해 주세요.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return '올바른 이메일 주소를 입력해 주세요.';
  }
  return null;
}

String? validateAuthPassword(String? value) {
  if ((value ?? '').length < 6) return '비밀번호는 6자 이상 입력해 주세요.';
  return null;
}

String? validatePasswordConfirmation(String password, String? confirmation) {
  if (confirmation == null || confirmation.isEmpty) {
    return '비밀번호를 한 번 더 입력해 주세요.';
  }
  if (password != confirmation) return '두 비밀번호가 일치하지 않습니다.';
  return null;
}
