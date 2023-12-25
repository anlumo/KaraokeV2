import 'package:flutter/material.dart';

class Search extends StatelessWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          SearchAnchor(
            builder: (context, controller) => SearchBar(
              controller: controller,
              padding: const MaterialStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
              onTap: () {
                controller.openView();
              },
              onChanged: (_) {
                controller.openView();
              },
              leading: const Icon(Icons.search),
              trailing: [
                Tooltip(
                  message: 'Random pick',
                  child: IconButton(onPressed: () {}, icon: const Icon(Icons.casino)),
                ),
              ],
            ),
            suggestionsBuilder: (context, controller) => List<ListTile>.generate(5, (int index) {
              final item = 'item $index';
              return ListTile(
                title: Text(item),
                onTap: () {
                  controller.closeView(item);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
