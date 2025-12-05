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
      size: Size(400, 20),
      alwaysOnTop: true,
      skipTaskbar: true,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.setAsFrameless();

      final display = await screenRetriever.getPrimaryDisplay();
      final screenWidth = display.size.width;
      final screenHeight = display.size.height;

      await windowManager.setPosition(
        Offset(
          (screenWidth / 2) - 200,
          screenHeight - 40,
        ),
      );
    });

    runApp(FloatingBarApp());
  } else {
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
            Text('Floating bar is active at bottom'),
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
  bool isHorizontal = true;
  Size? screenSize;

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

    double x = position.dx;
    double y = position.dy;
    bool shouldBeHorizontal = false;

    if (y <= 50) {
      y = 20;
      shouldBeHorizontal = true;
    } else if (y >= screenSize!.height - 70) {
      y = screenSize!.height - 40;
      shouldBeHorizontal = true;
    } else {
      shouldBeHorizontal = false;
    }

    if (isHorizontal != shouldBeHorizontal) {
      setState(() {
        isHorizontal = shouldBeHorizontal;
      });

      if (isHorizontal) {
        await windowManager.setSize(Size(400, 20));
        x = x.clamp(0.0, screenSize!.width - 400);
      } else {
        await windowManager.setSize(Size(20, 400));
        x = x.clamp(0.0, screenSize!.width - 20);
        y = y.clamp(0.0, screenSize!.height - 400);
      }
    } else {
      if (isHorizontal) {
        x = x.clamp(0.0, screenSize!.width - 400);
      } else {
        x = x.clamp(0.0, screenSize!.width - 20);
        y = y.clamp(0.0, screenSize!.height - 400);
      }
    }

    await windowManager.setPosition(Offset(x, y));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        windowManager.startDragging();
      },
      onPanEnd: (details) {
        _handleDragEnd();
      },
      child: Container(
        width: isHorizontal ? 400 : 20,
        height: isHorizontal ? 20 : 400,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4), // 4px border radius
        ),
        child: Stack(
          children: [
            // Drag handle - 9 dots
            Positioned(
              left: isHorizontal ? 10 : 0,
              top: isHorizontal ? 0 : 10,
              child: Container(
                width: isHorizontal ? 40 : 20,
                height: isHorizontal ? 20 : 40,
                child: Center(
                  child: Icon(
                    Icons.apps,
                    color: Colors.grey.shade600,
                    size: 14,
                  ),
                ),
              ),
            ),

            // Project name
            Center(
              child: isHorizontal
                  ? Text(
                'Desktop App',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              )
                  : RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'Desktop App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

            // Close button
            Positioned(
              right: isHorizontal ? 5 : 0,
              bottom: isHorizontal ? 0 : 5,
              child: Container(
                width: isHorizontal ? 30 : 20,
                height: isHorizontal ? 20 : 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () async {
                    await windowManager.close();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}