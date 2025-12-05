import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'dart:io';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();

  if (windowController.arguments == 'floating_bar') {
    // Platform-specific setup
    if (Platform.isWindows) {
      await _setupWindowsFloatingBar();
    } else if (Platform.isMacOS) {
      await _setupMacOSFloatingBar();
    }

    runApp(FloatingBarApp());
  } else {
    // Main app setup
    WindowOptions mainWindowOptions = const WindowOptions(
      size: Size(800, 600),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(mainWindowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(MainApp());
  }
}

// Windows floating bar setup
Future<void> _setupWindowsFloatingBar() async {
  WindowOptions windowOptions = const WindowOptions(
    size: Size(20, 400),
    alwaysOnTop: true,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.black,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setResizable(false);
    await windowManager.setBackgroundColor(Colors.black);

    final display = await screenRetriever.getPrimaryDisplay();
    final screenWidth = display.size.width;
    final screenHeight = display.size.height;

    await windowManager.setPosition(
      Offset(
        (screenWidth / 2) - 10,
        screenHeight - 420,
      ),
    );

    await windowManager.show();
  });
}

// macOS floating bar setup
Future<void> _setupMacOSFloatingBar() async {
  WindowOptions windowOptions = const WindowOptions(
    size: Size(20, 400),
    alwaysOnTop: true,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setResizable(false);
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(Colors.transparent);

    final display = await screenRetriever.getPrimaryDisplay();
    final screenWidth = display.size.width;
    final screenHeight = display.size.height;

    await windowManager.setPosition(
      Offset(
        (screenWidth / 2) - 10,
        screenHeight - 420,
      ),
    );

    await windowManager.show();
  });
}

class MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), _openFloatingBar);
  }

  Future<void> _openFloatingBar() async {
    final controllers = await WindowController.getAll();
    for (var controller in controllers) {
      if (controller.arguments == 'floating_bar') {
        return;
      }
    }

    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: false,
        arguments: 'floating_bar',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('StaffCo Main')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer, size: 80),
            SizedBox(height: 20),
            Text('Floating bar is active'),
          ],
        ),
      ),
    );
  }
}

class FloatingBarApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Platform-specific background
    final bgColor = Platform.isWindows ? Colors.black : Colors.transparent;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: bgColor,
        body: FloatingBarWidget(),
      ),
    );
  }
}

class FloatingBarWidget extends StatefulWidget {
  @override
  State<FloatingBarWidget> createState() => _FloatingBarWidgetState();
}

class _FloatingBarWidgetState extends State<FloatingBarWidget> {
  Size? screenSize;
  bool isDragging = false;

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

    setState(() {
      isDragging = false;
    });

    final position = await windowManager.getPosition();

    double x = position.dx;
    double y = position.dy;

    x = x.clamp(0.0, screenSize!.width - 20);
    y = y.clamp(0.0, screenSize!.height - 400);

    await windowManager.setPosition(Offset(x, y));
  }

  @override
  Widget build(BuildContext context) {
    // Platform-specific cursor
    final dragCursor = Platform.isWindows
        ? SystemMouseCursors.move
        : SystemMouseCursors.grab;
    final draggingCursor = Platform.isWindows
        ? SystemMouseCursors.grabbing
        : SystemMouseCursors.grabbing;

    return MouseRegion(
      cursor: isDragging ? draggingCursor : dragCursor,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            isDragging = true;
          });
        },
        onPanUpdate: (details) {
          windowManager.startDragging();
        },
        onPanEnd: (details) {
          _handleDragEnd();
        },
        child: Container(
          width: 20,
          height: 400,
          decoration: BoxDecoration(
            color: Colors.black,
            // macOS: no border radius, Windows: also no border radius
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            children: [
              Container(
                height: 60,
                child: Center(
                  child: Icon(
                    Icons.apps,
                    color: Colors.grey.shade600,
                    size: 14,
                  ),
                ),
              ),

              Spacer(),

              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'Desktop App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),

              Spacer(),

              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () async {
                    await windowManager.close();
                  },
                  child: Container(
                    height: 40,
                    child: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                      size: 14,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}