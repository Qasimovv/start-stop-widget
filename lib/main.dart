import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();

  if (windowController.arguments == 'floating_bar') {
    WindowOptions windowOptions = const WindowOptions(
      size: Size(20, 400),
      alwaysOnTop: true,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setAsFrameless();
      await windowManager.show();

      final display = await screenRetriever.getPrimaryDisplay();
      final screenWidth = display.size.width;
      final screenHeight = display.size.height;

      await windowManager.setPosition(
        Offset(
          (screenWidth / 2) - 10,
          screenHeight - 420,
        ),
      );
    });

    runApp(FloatingBarApp());
  } else {
    WindowOptions mainWindowOptions = const WindowOptions(
      size: Size(800, 600),
      center: true,
      backgroundColor: Colors.white,
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
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
    _setupWindow();
    _getScreenSize();
  }

  Future<void> _setupWindow() async {
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setAsFrameless();
    await windowManager.setSkipTaskbar(true);
    await windowManager.setHasShadow(true);
    await windowManager.setResizable(false);
    await windowManager.setBackgroundColor(Colors.transparent);
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
    return MouseRegion(
      cursor: isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
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
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 20,
            height: 400,
            color: Colors.black,
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
      ),
    );
  }
}