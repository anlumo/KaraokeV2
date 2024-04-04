import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/widgets/song_card.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:timer_builder/timer_builder.dart';
import 'package:uuid/uuid.dart';

class _AddDialog extends StatefulWidget {
  const _AddDialog({required this.song, required this.api, required this.playlistCubit});

  final Song song;
  final ServerApi api;
  final PlaylistCubit playlistCubit;

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

  @override
  void dispose() {
    _singerController.dispose();
    super.dispose();
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
      insetPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      contentPadding: const EdgeInsets.all(16),
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
          SongCard(
            song: widget.song,
            api: widget.api,
            disabled: true,
          ),
          BlocBuilder<PlaylistCubit, PlaylistState>(
            bloc: widget.playlistCubit,
            builder: (context, state) {
              String? helperText;
              if (state.songQueue.isNotEmpty) {
                final prediction = state.songQueue.last.predictedEnd?.difference(DateTime.now().toUtc());
                if (!(prediction?.isNegative ?? true)) {
                  helperText = context.t.search.addDialog.playPrediction(min: prediction!.inMinutes);
                }
              }
              return TimerBuilder.periodic(const Duration(seconds: 10), builder: (context) {
                return TextField(
                  autofocus: true,
                  controller: _singerController,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: context.t.search.addDialog.singerTextTitle(n: widget.song.duet ? 2 : 1),
                    helperText: helperText,
                  ),
                  onSubmitted: (text) => _submit(context),
                );
              });
            },
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
  required PlaylistCubit playlistCubit,
}) =>
    showDialog<UuidValue>(
      context: context,
      builder: (context) => _AddDialog(
        song: song,
        api: api,
        playlistCubit: playlistCubit,
      ),
    );
