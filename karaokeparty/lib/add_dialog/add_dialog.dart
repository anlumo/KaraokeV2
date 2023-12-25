import 'package:flutter/material.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/model/song.dart';
import 'package:karaokeparty/widgets/song_card.dart';
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

  @override
  void initState() {
    super.initState();
    _singerController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t.search.addDialog.title),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop(null);
            },
            child: Text(context.t.search.addDialog.cancelButton)),
        OutlinedButton(
          onPressed: _singerController.text.isNotEmpty ? () {} : null,
          child: Text(context.t.search.addDialog.submitButton),
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
                    Navigator.of(context).pop(null);
                    final song = await widget.api.fetchRandomSong();
                    if (song != null && context.mounted) {
                      showAddSongDialog(context, song: song, api: widget.api);
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
          ),
        ],
      ),
    );
  }
}

Future<UuidValue?> showAddSongDialog(
  BuildContext context, {
  required Song song,
  required ServerApi api,
}) =>
    showDialog<UuidValue>(
      context: context,
      builder: (context) => _AddDialog(song: song, api: api),
    );
