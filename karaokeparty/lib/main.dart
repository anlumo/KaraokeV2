import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/playlist_cubit.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/browse/browse.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/now_playing/now_playing.dart';
import 'package:karaokeparty/playlist/playlist.dart';
import 'package:karaokeparty/search/search.dart';
import 'package:logger/logger.dart';

final log = Logger(
  printer: PrettyPrinter(
    methodCount: 2, // Number of method calls to be displayed
    errorMethodCount: 8, // Number of method calls if stacktrace is provided
    lineLength: 80, // Width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    printTime: true, // Should each log print contain a timestamp
  ),
);

void main() {
  log.d('Starting application');
  runApp(TranslationProvider(child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDark = false;
  final server = ServerApi();
  final songCache = SongCache();

  @override
  void initState() {
    super.initState();
    server.connect();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karaoke Party',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Colors.deepOrange, brightness: isDark ? Brightness.dark : Brightness.light),
        useMaterial3: true,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder(
          stream: server.connectedController.stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data is ConnectingState) {
              final theme = Theme.of(context);
              return ColoredBox(
                color: theme.colorScheme.background,
                child: Center(
                    child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 60, height: 60, child: CircularProgressIndicator()),
                        const SizedBox(
                          height: 16,
                        ),
                        Text(
                          context.t.core.connection.connectingToServerOverlay,
                          style: theme.textTheme.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                )),
              );
            }
            switch (snapshot.data!) {
              case ConnectingState(): // can't happen
                throw '';
              case ConnectionFailedState():
                return AlertDialog(
                  title: Text(context.t.core.connection.connectionFailedError),
                  content: Text((snapshot.data! as ConnectionFailedState).description(context)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        server.connect();
                      },
                      child: Text(context.t.core.connection.retryButton),
                    ),
                  ],
                );
              case ConnectedState():
                return BlocProvider.value(
                  value: server.playlist,
                  child: DefaultTabController(
                    length: 3,
                    child: Scaffold(
                      appBar: AppBar(
                        title: Text(context.t.core.title),
                        bottom: const TabBar(tabs: [
                          Tab(icon: Icon(Icons.search)),
                          Tab(icon: Icon(Icons.library_music)),
                          Tab(icon: Icon(Icons.mic_external_on)),
                        ]),
                        actions: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  isDark = !isDark;
                                });
                              },
                              isSelected: isDark,
                              icon: const Icon(Icons.wb_sunny_outlined),
                              selectedIcon: const Icon(Icons.brightness_2_outlined),
                            ),
                          ),
                        ],
                      ),
                      body: Column(
                        children: [
                          Expanded(
                            child: TabBarView(children: [
                              const Search(),
                              const Browse(),
                              Playlist(
                                songCache: songCache,
                              ),
                            ]),
                          ),
                          NowPlaying(
                            songCache: songCache,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
            }
          }),
    );
  }
}
