import 'package:flutter/material.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/main.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';

class SuggestSong extends StatefulWidget {
  const SuggestSong({super.key, required this.failedSearch, required this.api});

  final String failedSearch;
  final ServerApi api;

  @override
  State<SuggestSong> createState() => _SuggestSongState();
}

class _SuggestSongState extends State<SuggestSong> {
  final _explanationController = TextEditingController();
  final _nameController = TextEditingController();
  final _submitButtonController = RoundedLoadingButtonController();
  var _loading = false;
  var _submitted = false;

  @override
  void initState() {
    super.initState();
    _explanationController.text = widget.failedSearch;
  }

  @override
  void didUpdateWidget(covariant SuggestSong oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.failedSearch != widget.failedSearch) {
      _submitButtonController.reset();
      _explanationController.text = widget.failedSearch;
      _submitted = false;
      _loading = false;
    }
  }

  @override
  void dispose() {
    _explanationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
    });
    try {
      await widget.api.suggestSong(
        name: _nameController.text,
        suggestion: _explanationController.text,
      );
      _submitButtonController.success();
    } catch (e) {
      log.e(e);
      _submitButtonController.error();
    }
    setState(() {
      _loading = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: Card(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _submitted
                ? Text(
                    context.t.search.suggestSong.submissionDone,
                    style: theme.textTheme.titleLarge,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t.search.suggestSong.explanation,
                        style: theme.textTheme.labelLarge,
                      ),
                      TextField(
                        controller: _explanationController,
                        maxLines: null,
                        enabled: !_loading,
                        onSubmitted: (_) {
                          if (!_loading && _explanationController.text.isNotEmpty) {
                            _submit();
                          }
                        },
                      ),
                      TextField(
                        decoration: InputDecoration(
                          labelText: context.t.search.suggestSong.yourName,
                        ),
                        controller: _nameController,
                        enabled: !_loading,
                        onSubmitted: (_) {
                          if (!_loading && _explanationController.text.isNotEmpty) {
                            _submit();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: RoundedLoadingButton(
                          controller: _submitButtonController,
                          color: theme.colorScheme.primary,
                          onPressed: !_loading && _explanationController.text.isNotEmpty ? _submit : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              context.t.search.suggestSong.submitButtonTitle,
                              style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onPrimary),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
