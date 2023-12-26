import 'package:flutter/material.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';

class _LoginDialog extends StatefulWidget {
  const _LoginDialog({required this.connection});

  final ConnectionCubit connection;

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _submitButtonController = RoundedLoadingButtonController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode(debugLabel: 'password');
  var submitting = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  Size _textSize(String text, TextStyle style) {
    final TextPainter textPainter =
        TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr)
          ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  Future<void> _submit(BuildContext context) async {
    final success = await widget.connection.login(_passwordController.text);

    if (success) {
      _submitButtonController.success();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      _submitButtonController.error();
      await Future.delayed(const Duration(seconds: 1));
      _submitButtonController.reset();
      _passwordFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitButtonTextSize = _textSize(
      context.t.login.loginButton,
      theme.textTheme.labelLarge!,
    );

    return AlertDialog(
      icon: const Icon(Icons.mic),
      title: Text(context.t.login.title),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(context.t.search.addDialog.cancelButton)),
        SizedBox(
          width: submitButtonTextSize.width + 64,
          child: RoundedLoadingButton(
            controller: _submitButtonController,
            color: theme.colorScheme.primary,
            onPressed: !submitting && _passwordController.text.isNotEmpty ? () => _submit(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                context.t.login.loginButton,
                style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
        ),
      ],
      content: TextField(
        focusNode: _passwordFocus,
        controller: _passwordController,
        autofocus: true,
        autofillHints: const [AutofillHints.password],
        obscureText: true,
        decoration: InputDecoration(labelText: context.t.login.passwordPrompt),
        onSubmitted: (_) {
          _submit(context);
        },
      ),
    );
  }
}

Future<String?> showLoginDialog(BuildContext context, ConnectionCubit connection) => showDialog<String?>(
      context: context,
      builder: (context) => _LoginDialog(connection: connection),
    );
