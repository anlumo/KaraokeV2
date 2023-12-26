import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/browse/browse.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/login/login.dart';
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
      home: BlocBuilder(
        bloc: server.connectionCubit,
        builder: (context, connectionState) {
          switch (connectionState) {
            case InitialWebSocketConnectionState():
            case WebSocketConnectingState():
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
            case WebSocketConnectionFailedState():
              return AlertDialog(
                title: Text(context.t.core.connection.connectionFailedError),
                content: Text(connectionState.description(context)),
                actions: [
                  TextButton(
                    onPressed: () {
                      server.connectionCubit.connect(server.playlist);
                    },
                    child: Text(context.t.core.connection.retryButton),
                  ),
                ],
              );
            case WebSocketConnectedState(:final isAdmin):
              return MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: server.playlist),
                  BlocProvider.value(value: server.connectionCubit),
                ],
                child: DefaultTabController(
                  length: 3,
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(context.t.core.title),
                      bottom: TabBar(tabs: [
                        Tooltip(
                          message: context.t.core.searchTabTooltip,
                          child: const Tab(icon: Icon(Icons.search)),
                        ),
                        Tooltip(
                          message: context.t.core.masterListTooltip,
                          child: const Tab(icon: Icon(Icons.library_music)),
                        ),
                        Tooltip(
                          message: context.t.core.playlistTooltip,
                          child: const Tab(icon: Icon(Icons.mic_external_on)),
                        ),
                      ]),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Tooltip(
                            message: context.t.core.adminModeButtonTooltip,
                            child: TextButton(
                              onPressed: () {
                                if (isAdmin) {
                                  server.connectionCubit.logout();
                                } else {
                                  showLoginDialog(context, server.connectionCubit);
                                }
                              },
                              child:
                                  Text(isAdmin ? context.t.core.logoutAdminModeTitle : context.t.core.adminModeTitle),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Tooltip(
                            message: context.t.core.darkModeButtonTooltip,
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
                        ),
                      ],
                    ),
                    body: Builder(builder: (context) {
                      return BlocBuilder<ConnectionCubit, WebSocketConnectionState>(
                        buildWhen: (previous, current) {
                          if (current is WebSocketConnectedState &&
                              current.isAdmin &&
                              (previous is! WebSocketConnectedState || !previous.isAdmin)) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(context.t.login.loggedInSnackbar),
                            ));
                          }
                          return false;
                        },
                        builder: (context, connectionState) {
                          return Column(
                            children: [
                              Expanded(
                                child: TabBarView(children: [
                                  Search(api: server),
                                  Browse(api: server),
                                  Playlist(
                                    songCache: songCache,
                                    api: server,
                                  ),
                                ]),
                              ),
                              NowPlaying(
                                songCache: songCache,
                                api: server,
                              ),
                            ],
                          );
                        },
                      );
                    }),
                  ),
                ),
              );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
