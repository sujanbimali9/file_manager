import 'package:file_managers/app/modules/file_pages/views/file_pages_view.dart';
import 'package:file_managers/app/modules/home/views/home_view.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  runApp(
    MaterialApp(
      title: "Application",
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeView(),
        '/file_view': (context) => const FilePagesView()
      },
    ),
  );
}
