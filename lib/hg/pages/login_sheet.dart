import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_controllers.dart';
import '../theme/hg_theme.dart';
import '../utils/hg_format.dart';

Future<bool> ensureLoggedIn(BuildContext context) async {
  final auth = context.read<AuthController>();
  if (auth.isLoggedIn) return true;
  final result = await showLoginSheet(context);
  return result ?? false;
}

Future<bool?> showLoginSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => const LoginSheet(),
  );
}

class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key});

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();

  bool _register = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthController>();
      if (_register) {
        await auth.register(_username.text, _password.text, email: _email.text);
      } else {
        await auth.login(_username.text, _password.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: height * 0.78),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 9, 20, 18),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E4E6),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF5F5F64),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _register ? '创建黄果账号' : '登录黄果',
                    style: const TextStyle(
                      color: Color(0xFF1E1E21),
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _register ? '注册后同步追剧、历史和互动记录' : '登录后同步追剧、历史和点赞记录',
                    style: const TextStyle(
                      color: Color(0xFF85858A),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _ModeTab(
                          label: '登录',
                          selected: !_register,
                          onTap: () => setState(() {
                            _register = false;
                            _error = null;
                          }),
                        ),
                        _ModeTab(
                          label: '注册',
                          selected: _register,
                          onTap: () => setState(() {
                            _register = true;
                            _error = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel('账号'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    style: const TextStyle(fontSize: 14),
                    decoration: _fieldDecoration(
                      hint: _register ? '4-20 位字母、数字或下划线' : '请输入黄果账号',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return '请输入账号';
                      if (_register &&
                          !RegExp(r'^[A-Za-z0-9_]{4,20}$').hasMatch(text)) {
                        return '账号需为 4-20 位字母、数字或下划线';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('密码'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: _register
                        ? TextInputAction.next
                        : TextInputAction.done,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    onFieldSubmitted: (_) => _register ? null : _submit(),
                    style: const TextStyle(fontSize: 14),
                    decoration: _fieldDecoration(
                      hint: _register ? '6-20 位，建议字母+数字' : '请输入密码',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF85858A),
                          size: 20,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.isEmpty) return '请输入密码';
                      if (text.length < 6 || text.length > 20) {
                        return '密码长度需为 6-20 位';
                      }
                      return null;
                    },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: !_register
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 14),
                              const _FieldLabel('邮箱（可选）'),
                              const SizedBox(height: 7),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                style: const TextStyle(fontSize: 14),
                                decoration: _fieldDecoration(
                                  hint: '用于接收账号通知',
                                  icon: Icons.alternate_email_rounded,
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isNotEmpty &&
                                      !RegExp(
                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                      ).hasMatch(text)) {
                                    return '邮箱格式不正确';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB8442C),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: HgColors.ink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFB9B9BD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _register ? '注册并登录' : '登录',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '凭据仅发送至黄果站点；果幕不保存密码。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFA0A0A4),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA2A2A6), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF85858A), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F5F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF242427), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD36B56)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD36B56), width: 1.2),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? HgColors.ink : const Color(0xFF85858A),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF5F5F64),
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
