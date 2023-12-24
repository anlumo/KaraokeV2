import 'package:flutter/material.dart';

class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 5,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(child: Text('Now playing')),
              Placeholder(
                fallbackHeight: 80,
                fallbackWidth: 80,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
