import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karaokeparty/api/api.dart';
import 'package:karaokeparty/api/cubit/connection_cubit.dart';
import 'package:karaokeparty/api/song_cache.dart';
import 'package:karaokeparty/browse/browse.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/intents.dart';
import 'package:karaokeparty/login/login.dart';
import 'package:karaokeparty/now_playing/now_playing.dart';
import 'package:karaokeparty/playlist/playlist.dart';
import 'package:karaokeparty/search/search.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const double wideLayoutSidebarWidth = 450;

void main() {
  log.d('Starting application');
  runApp(TranslationProvider(
      child: FutureBuilder(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return MyApp(
                sharedPreferences: snapshot.data!,
              );
            }
            return const SizedBox();
          })));
}

class MyApp extends StatefulWidget {
  const MyApp({required this.sharedPreferences, super.key});

  final SharedPreferences sharedPreferences;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDark = false;
  late final ServerApi server;
  final songCache = SongCache();

  @override
  void initState() {
    super.initState();
    isDark = widget.sharedPreferences.getBool('darkMode') ??
        (WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
    server = ServerApi(widget.sharedPreferences);
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
              final compactLayout = MediaQuery.sizeOf(context).width <= wideLayoutSidebarWidth * 2;

              return MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: server.playlist),
                  BlocProvider.value(value: server.connectionCubit),
                ],
                child: DefaultTabController(
                  length: compactLayout ? 3 : 2,
                  child: Builder(builder: (context) {
                    return Actions(
                      actions: {
                        SearchTabIntent: CallbackAction<SearchTabIntent>(onInvoke: (intent) {
                          DefaultTabController.of(context).index = 0;
                          return null;
                        }),
                        BrowseTabIntent: CallbackAction<BrowseTabIntent>(onInvoke: (intent) {
                          DefaultTabController.of(context).index = 1;
                          return null;
                        }),
                        if (compactLayout)
                          PlaylistTabIntent: CallbackAction<PlaylistTabIntent>(onInvoke: (intent) {
                            DefaultTabController.of(context).index = 2;
                            return null;
                          }),
                      },
                      child: Shortcuts(
                        shortcuts: {
                          const SingleActivator(LogicalKeyboardKey.digit1, control: true): const SearchTabIntent(),
                          const SingleActivator(LogicalKeyboardKey.digit2, control: true): const BrowseTabIntent(),
                          if (compactLayout)
                            const SingleActivator(LogicalKeyboardKey.digit3, control: true): const PlaylistTabIntent(),
                        },
                        child: Scaffold(
                          resizeToAvoidBottomInset: false,
                          appBar: AppBar(
                            title: Text(context.t.core.title),
                            bottom: TabBar(
                              tabs: [
                                Tooltip(
                                  message: context.t.core.searchTabTooltip,
                                  child: const Tab(icon: Icon(Icons.search)),
                                ),
                                Tooltip(
                                  message: context.t.core.masterListTooltip,
                                  child: const Tab(icon: Icon(Icons.library_music)),
                                ),
                                if (compactLayout)
                                  Tooltip(
                                    message: context.t.core.playlistTooltip,
                                    child: const Tab(icon: Icon(Icons.mic_external_on)),
                                  ),
                              ],
                              padding: compactLayout ? null : const EdgeInsets.only(right: wideLayoutSidebarWidth),
                            ),
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
                                    child: Text(
                                        isAdmin ? context.t.core.logoutAdminModeTitle : context.t.core.adminModeTitle),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Tooltip(
                                  message: context.t.core.darkModeButtonTooltip,
                                  child: IconButton(
                                    onPressed: () {
                                      server.connectionCubit.sharedPreferences.setBool('darkMode', !isDark);
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
                                    showCloseIcon: true,
                                  ));
                                }
                                return false;
                              },
                              builder: (context, connectionState) {
                                if (compactLayout) {
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
                                } else {
                                  final theme = Theme.of(context);
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: TabBarView(
                                          children: [
                                            Search(api: server),
                                            Browse(api: server),
                                          ],
                                        ),
                                      ),
                                      ColoredBox(
                                        color: theme.colorScheme.secondaryContainer,
                                        child: SizedBox(
                                          width: wideLayoutSidebarWidth,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: FocusTraversalGroup(
                                                    child: Playlist(songCache: songCache, api: server),
                                                  ),
                                                ),
                                                NowPlaying(songCache: songCache, api: server),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    ],
                                  );
                                }
                              },
                            );
                          }),
                        ),
                      ),
                    );
                  }),
                ),
              );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
