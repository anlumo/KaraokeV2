import 'package:flutter/material.dart';
import 'package:karaokeparty/browse/browse.dart';
import 'package:karaokeparty/i18n/strings.g.dart';
import 'package:karaokeparty/now_playing/now_playing.dart';
import 'package:karaokeparty/playlist/playlist.dart';
import 'package:karaokeparty/search/search.dart';

void main() {
  runApp(TranslationProvider(child: const MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDark = false;

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
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.t.core.title),
            bottom: const TabBar(tabs: [
              Tab(icon: Icon(Icons.search)),
              Tab(icon: Icon(Icons.list)),
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
          body: const Column(
            children: [
              Expanded(
                child: TabBarView(children: [
                  Search(),
                  Browse(),
                  Playlist(),
                ]),
              ),
              NowPlaying(),
            ],
          ),
        ),
      ),
    );
  }
}
