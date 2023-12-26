import 'package:flutter/material.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/widgets/song_card.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:uuid/uuid.dart';

class _AddDialog extends StatefulWidget {
  const _AddDialog({required this.song, required this.api});

  final Song song;
  final ServerApi api;

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _singerController = TextEditingController();
  final _submitButtonController = RoundedLoadingButtonController();
  var submitting = false;

  @override
  void initState() {
    super.initState();
    _singerController.addListener(() => setState(() {}));
  }

  Future<void> _submit(BuildContext context) async {
    final state = widget.api.connectionCubit.state;
    if (state is WebSocketConnectedState) {
      state.submitSong(singer: _singerController.text, songId: widget.song.id);
    }
    _submitButtonController.success();
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
      context.t.search.addDialog.submitButton,
      theme.textTheme.labelLarge!,
    );

    return AlertDialog(
      title: Text(context.t.search.addDialog.title),
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
            onPressed: !submitting && _singerController.text.isNotEmpty ? () => _submit(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                context.t.search.addDialog.submitButton,
                style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: SongCard(
                  song: widget.song,
                  api: widget.api,
                  disabled: true,
                ),
              ),
              Tooltip(
                message: context.t.search.randomPickButton,
                child: IconButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final songs = await widget.api.fetchRandomSongs(1);
                    if (songs != null && songs.length == 1 && context.mounted) {
                      showAddSongDialog(context, song: songs.first, api: widget.api);
                    }
                  },
                  icon: const Icon(Icons.casino),
                ),
              ),
            ],
          ),
          TextField(
            controller: _singerController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.t.search.addDialog.singerTextTitle,
            ),
            onSubmitted: (text) => _submit(context),
          ),
        ],
      ),
    );
  }
}

Future<void> showAddSongDialog(
  BuildContext context, {
  required Song song,
  required ServerApi api,
}) =>
    showDialog<UuidValue>(
      context: context,
      builder: (context) => _AddDialog(song: song, api: api),
    );
