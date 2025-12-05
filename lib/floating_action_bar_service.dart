import 'package:flutter/material.dart';

class FloatingBarService {
  static final FloatingBarService _instance = FloatingBarService._internal();
  factory FloatingBarService() => _instance;
  FloatingBarService._internal();

  OverlayEntry? _overlayEntry;
  final GlobalKey<_FloatingBarState> _barKey = GlobalKey();

  void show(BuildContext context, {
    required String message,
    String? buttonText,
    VoidCallback? onButtonPressed,
    Duration? duration,
  }) {
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => FloatingBar(
        key: _barKey,
        message: message,
        buttonText: buttonText,
        onButtonPressed: onButtonPressed,
        onDismiss: hide,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Auto-hide
    if (duration != null) {
      Future.delayed(duration, () => hide());
    }
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void updateMessage(String message) {
    _barKey.currentState?.updateMessage(message);
  }
}

class FloatingBar extends StatefulWidget {
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final VoidCallback onDismiss;

  const FloatingBar({
    Key? key,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<FloatingBar> createState() => _FloatingBarState();
}

class _FloatingBarState extends State<FloatingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  String _currentMessage = '';

  @override
  void initState() {
    super.initState();
    _currentMessage = widget.message;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void updateMessage(String message) {
    if (mounted) {
      setState(() {
        _currentMessage = message;
      });
    }
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2C),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (widget.buttonText != null && widget.onButtonPressed != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: TextButton(
                      onPressed: () {
                        widget.onButtonPressed?.call();
                        _dismiss();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        widget.buttonText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: _dismiss,
                  icon: const Icon(Icons.close, color: Colors.white70),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}