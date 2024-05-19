import 'package:flutter/material.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:rounded_loading_button_plus/rounded_loading_button.dart';

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog({required this.song, required this.api});

  final Song song;
  final ServerApi api;

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final _reportController = TextEditingController();
  final _submitButtonController = RoundedLoadingButtonController();
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _reportController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    setState(() {
      _submitting = true;
    });
    final state = widget.api.connectionCubit.state;
    if (state is WebSocketConnectedState) {
      state.reportBug(widget.song.id, _reportController.text);
    }
    _submitButtonController.success();
    _submitting = false;
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Size _textSize(String text, TextStyle style) {
    final TextPainter textPainter =
        TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr)
          ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitButtonTextSize = _textSize(
      context.t.playlist.bugReport.submitButton,
      theme.textTheme.labelLarge!,
    );

    return AlertDialog(
      title: Text(context.t.playlist.bugReport.title(title: widget.song.title)),
      scrollable: true,
      content: SizedBox(
        width: 300,
        child: TextField(
          autofocus: true,
          controller: _reportController,
          maxLines: null,
          decoration: InputDecoration(
            labelText: context.t.playlist.bugReport.textFieldLabel,
          ),
          onSubmitted: (_) => _submit(context),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(context.t.playlist.bugReport.cancelButton)),
        SizedBox(
          width: submitButtonTextSize.width + 64,
          child: RoundedLoadingButton(
            controller: _submitButtonController,
            color: theme.colorScheme.primary,
            onPressed: !_submitting && _reportController.text.isNotEmpty ? () => _submit(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                context.t.playlist.bugReport.submitButton,
                style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showBugReportDialog(BuildContext context, {required Song song, required ServerApi api}) =>
    showDialog<void>(
      context: context,
      builder: (context) => _BugReportDialog(song: song, api: api),
    );
