import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();

  if (windowController.arguments == 'floating_bar') {
    await _setupFloatingBar();
    runApp(FloatingBarApp());
  } else {
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(size: Size(800, 600)),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
    runApp(MainApp());
  }
}

Future<void> _setupFloatingBar() async {
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(30, 410),
      alwaysOnTop: true,
      skipTaskbar: true,

      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    ),
    () async {
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setResizable(false);
      await windowManager.setBackgroundColor(Colors.transparent);

      final display = await screenRetriever.getPrimaryDisplay();

      final double windowWidth = 30;
      final double windowHeight = 410;

      await windowManager.setPosition(
        Offset(
          display.size.width - windowWidth - 10,
          (display.size.height - windowHeight) / 2,
        ),
      );

      await windowManager.show();
    },
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), _openFloatingBar);
  }

  Future<void> _openFloatingBar() async {
    final controllers = await WindowController.getAll();
    if (controllers.any((c) => c.arguments == 'floating_bar')) return;

    await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: false, arguments: 'floating_bar'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center()),
    );
  }
}

class FloatingBarApp extends StatefulWidget {
  const FloatingBarApp({super.key});

  @override
  State<FloatingBarApp> createState() => _FloatingBarAppState();
}

class _FloatingBarAppState extends State<FloatingBarApp> {
  Size? screenSize;

  @override
  void initState() {
    super.initState();
    _getScreenSize();
  }

  Future<void> _getScreenSize() async {
    final display = await screenRetriever.getPrimaryDisplay();
    setState(() {
      screenSize = display.size;
    });
  }

  Future<void> _handleDragEnd() async {
    if (screenSize == null) return;

    final position = await windowManager.getPosition();
    await windowManager.setPosition(
      Offset(
        position.dx.clamp(0.0, screenSize!.width - 30),
        position.dy.clamp(0.0, screenSize!.height - 410),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
        width: 30,
        height: 410,
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: GestureDetector(
                onPanUpdate: (_) => windowManager.startDragging(),
                onPanEnd: (_) => _handleDragEnd(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Icon(
                    Icons.drag_handle,
                    color: Colors.grey,
                    size: 18,
                  ),
                ),
              ),
            ),

            // BOTTOM CANCEL ICON
            GestureDetector(
              onTap: () {
                windowManager.close();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Icon(
                  Icons.close,
                  color: Colors.grey,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

