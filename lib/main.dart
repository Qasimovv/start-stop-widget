import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'dart:async';

// Global channels
const kTimerChannel = WindowMethodChannel('timer_sync');
const kVisibilityChannel = WindowMethodChannel('visibility_sync');

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
  int _seconds = 0;
  bool _isRunning = false;
  bool _isFloatingBarVisible = true;
  Timer? _timer;
  WindowController? _floatingController;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 500), _openFloatingBar);
    _setupChannels();
  }

  void _setupChannels() {
    kTimerChannel.setMethodCallHandler((call) async {
      if (call.method == 'sync_timer') {
        setState(() {
          _seconds = call.arguments['seconds'] as int;
          _isRunning = call.arguments['isRunning'] as bool;
        });
        if (_isRunning) {
          _startTimer();
        } else {
          _stopTimer();
        }
      }
    });

    kVisibilityChannel.setMethodCallHandler((call) async {
      if (call.method == 'bar_hidden') {
        setState(() {
          _isFloatingBarVisible = false;
        });
      } else if (call.method == 'bar_shown') {
        setState(() {
          _isFloatingBarVisible = true;
        });
      }
    });
  }

  Future<void> _openFloatingBar() async {
    final controllers = await WindowController.getAll();
    if (controllers.any((c) => c.arguments == 'floating_bar')) return;

    _floatingController = await WindowController.create(
      WindowConfiguration(hiddenAtLaunch: false, arguments: 'floating_bar'),
    );
  }

  Future<void> _toggleFloatingBar() async {
    try {
      if (_floatingController == null) {
        final controllers = await WindowController.getAll();
        _floatingController = controllers.firstWhere(
              (c) => c.arguments == 'floating_bar',
          orElse: () => throw Exception('Floating bar not found'),
        );
      }

      setState(() => _isFloatingBarVisible = !_isFloatingBarVisible);

      // Notify floating bar to hide/show itself
      try {
        await kVisibilityChannel.invokeMethod(
          _isFloatingBarVisible ? 'show_bar' : 'hide_bar',
        );
      } catch (e) {
        print('Error sending visibility command: $e');
      }
    } catch (e) {
      print('Error toggling floating bar: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      _broadcastTimer();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _toggleTimer() {
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) {
      _startTimer();
    } else {
      _stopTimer();
    }
    _broadcastTimer();
  }

  Future<void> _broadcastTimer() async {
    try {
      await kTimerChannel.invokeMethod('sync_timer', {
        'seconds': _seconds,
        'isRunning': _isRunning,
      });
    } catch (e) {
      // Floating window might not be open
    }
  }

  String _formatTime() {
    final hours = _seconds ~/ 3600;
    final minutes = (_seconds % 3600) ~/ 60;
    final secs = _seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatTime(),
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleTimer,
                child: Text(_isRunning ? 'Stop' : 'Start'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _toggleFloatingBar,
                child: Text(_isFloatingBarVisible ? 'Hide Bar' : 'Show Bar'),
              ),
            ],
          ),
        ),
      ),
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
  int _seconds = 0;
  bool _isRunning = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _getScreenSize();
    _setupChannels();
  }

  void _setupChannels() {
    kTimerChannel.setMethodCallHandler((call) async {
      if (call.method == 'sync_timer') {
        setState(() {
          _seconds = call.arguments['seconds'] as int;
          _isRunning = call.arguments['isRunning'] as bool;
        });
        if (_isRunning) {
          _startTimer();
        } else {
          _stopTimer();
        }
      }
    });

    kVisibilityChannel.setMethodCallHandler((call) async {
      if (call.method == 'hide_bar') {
        await windowManager.hide();
      } else if (call.method == 'show_bar') {
        await windowManager.show();
      }
    });
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

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      _broadcastTimer();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _toggleTimer() {
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) {
      _startTimer();
    } else {
      _stopTimer();
    }
    _broadcastTimer();
  }

  Future<void> _broadcastTimer() async {
    try {
      await kTimerChannel.invokeMethod('sync_timer', {
        'seconds': _seconds,
        'isRunning': _isRunning,
      });
    } catch (e) {
      // Main window might not be listening
    }
  }

  Future<void> _hideFloatingBar() async {
    await windowManager.hide();
    // Notify main app
    try {
      await kVisibilityChannel.invokeMethod('bar_hidden');
    } catch (e) {
      print('Error notifying main: $e');
    }
  }

  String _formatTime() {
    final hours = _seconds ~/ 3600;
    final minutes = (_seconds % 3600) ~/ 60;
    final secs = _seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

              // Timer display
              Expanded(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: Text(
                      _formatTime(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              // Start/Stop button
              GestureDetector(
                onTap: _toggleTimer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Icon(
                    _isRunning ? Icons.pause : Icons.play_arrow,
                    color: _isRunning ? Colors.red : Colors.green,
                    size: 18,
                  ),
                ),
              ),

              // Cancel/Hide button
              GestureDetector(
                onTap: _hideFloatingBar,
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