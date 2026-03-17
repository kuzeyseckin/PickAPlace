import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:rxdart/rxdart.dart';
import 'package:pick_a_place/models/restaurants_model.dart';
import 'package:pick_a_place/models/ad_manager.dart';
import 'package:pick_a_place/models/analytics_service.dart';

class RouletteDialog extends StatefulWidget {
  final List<Restaurant> selectedRestaurants;
  final Function(Restaurant) onWinnerFound;

  const RouletteDialog({
    super.key,
    required this.selectedRestaurants,
    required this.onWinnerFound,
  });

  @override
  State<RouletteDialog> createState() => _RouletteDialogState();
}

class _RouletteDialogState extends State<RouletteDialog>
    with TickerProviderStateMixin {
  final selected = BehaviorSubject<int>();
  int _winnerIndex = 0;
  bool _isSpinning = false;
  bool _isWinnerMode = false;

  bool _hasAdShown = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _lightLoopController;
  late AnimationController _blinkController;

  late final List<FortuneItem> _cachedItems;
  late final List<Color> _sliceColors;

  static const List<Offset> _lightOffsets = [
    Offset(0.400, -0.610),
    Offset(0.669, -0.28),
    Offset(0.723, -0.023),
    Offset(0.663, 0.257),
    Offset(0.403, 0.568),
    Offset(-0.002, 0.697),
    Offset(-0.409, 0.568),
    Offset(-0.670, 0.257),
    Offset(-0.723, -0.017),
    Offset(-0.671, -0.284),
    Offset(-0.403, -0.611),
  ];

  static const double _yOffset = -0.02;
  static const double _sizeRatio = 0.746;
  static const double _radiusScale = 0.53;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logRouletteOpened(widget.selectedRestaurants.length);
    _sliceColors = const [
      Color(0xFFFF0033),
      Color(0xFFFF8C00),
      Color(0xFFFFD700),
      Color(0xFFADFF2F),
      Color(0xFF00C853),
      Color(0xFF00E5FF),
      Color(0xFF00BCD4),
      Color(0xFF2979FF),
      Color(0xFF3D5AFE),
      Color(0xFF651FFF),
      Color(0xFFFF00FF),
      Color(0xFFF50057),
    ];

    _cachedItems = _buildCachedItems();
    _initAnimations();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _lightLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  List<FortuneItem> _buildCachedItems() {
    return List.generate(
      widget.selectedRestaurants.length,
      (i) => FortuneItem(
        child: _buildSliceText(widget.selectedRestaurants[i].name),
        style: FortuneItemStyle(
          color: _sliceColors[i % _sliceColors.length],
          borderColor: Colors.black,
          borderWidth: 3.5,
        ),
      ),
    );
  }

  Widget _buildSliceText(String name) {
    return Padding(
      padding: const EdgeInsets.only(left: 35.0, right: 10.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          children: [
            Text(
              name,
              maxLines: 1,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = Colors.black,
              ),
            ),
            Text(
              name,
              maxLines: 1,
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 2.0,
                    color: Colors.black54,
                    offset: Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    selected.close();
    _pulseController.dispose();
    _lightLoopController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  void _spinTheWheel() {
    if (_isSpinning) return;

    void startSpinningAnimation() {
      AnalyticsService().logRouletteSpinStarted();
      _pulseController.stop();
      setState(() => _isSpinning = true);
      _winnerIndex = math.Random().nextInt(widget.selectedRestaurants.length);
      selected.add(_winnerIndex);
    }

    if (_hasAdShown) {
      startSpinningAnimation();
      return;
    }

    if (AdManager.instance.isInterstitialLoaded) {
      AdManager.instance.showInterstitialAd(
        onAdDismissed: () {
          setState(() {
            _hasAdShown = true;
            startSpinningAnimation();
          });
        },
      );
    } else {
      AnalyticsService().logAdSkippedNotReady();
      startSpinningAnimation();
    }
  }

  void _onSpinComplete() {
    final winner = widget.selectedRestaurants[_winnerIndex];

    AnalyticsService().logRouletteWinner(
      winnerName: winner.name,
      category: winner.category,
      distanceKm: winner.distanceKm,
      totalRestaurants: widget.selectedRestaurants.length,
    );
    AnalyticsService().setUserProperties(
      totalRestaurantsSelected: widget.selectedRestaurants.length,
    );
    setState(() => _isWinnerMode = true);
    _blinkController.repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        Navigator.pop(context);
        widget.onWinnerFound(widget.selectedRestaurants[_winnerIndex]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dimensions = _calculateDimensions(size);

    return PopScope(
      canPop: true,

      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          if (!_isWinnerMode) {
            AnalyticsService().logRouletteCancelled();
          }
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          width: dimensions.width,
          height: dimensions.height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildWheel(dimensions.width),
              _buildFrame(),
              _buildLights(),
              _buildCenterButton(dimensions.width),
            ],
          ),
        ),
      ),
    );
  }

  ({double width, double height}) _calculateDimensions(Size screenSize) {
    double width = screenSize.width * 0.9;
    double height = width * 1.3;

    if (height > screenSize.height * 0.8) {
      height = screenSize.height * 0.8;
      width = height / 1.3;
    }

    return (width: width, height: height);
  }

  Widget _buildWheel(double containerWidth) {
    return Align(
      alignment: const Alignment(0, _yOffset),
      child: SizedBox(
        width: containerWidth * _sizeRatio,
        height: containerWidth * _sizeRatio,
        child: FortuneWheel(
          selected: selected.stream,
          animateFirst: false,
          physics: CircularPanPhysics(
            duration: const Duration(seconds: 5),
            curve: Curves.decelerate,
          ),
          onAnimationEnd: _onSpinComplete,
          indicators: const [],
          items: _cachedItems,
        ),
      ),
    );
  }

  Widget _buildFrame() {
    return Positioned.fill(
      child: Image.asset(
        'assets/images/roulette_wheel/deneme_wheel25.png',
        fit: BoxFit.contain,
        alignment: const Alignment(0, 0),
      ),
    );
  }

  Widget _buildLights() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _isWinnerMode ? _blinkController : _lightLoopController,
        builder: (context, _) {
          return CustomPaint(
            painter: OptimizedLightPainter(
              progress: _lightLoopController.value,
              blinkValue: _blinkController.value,
              isWinnerMode: _isWinnerMode,
              offsets: _lightOffsets,
              radiusScale: _radiusScale,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenterButton(double containerWidth) {
    return Align(
      alignment: const Alignment(0, -0.01),
      child: GestureDetector(
        onTap: _spinTheWheel,
        child: Container(
          width: containerWidth * 0.1,
          height: containerWidth * 0.4,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
          ),
          child: _isSpinning
              ? null
              : ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class OptimizedLightPainter extends CustomPainter {
  final double progress;
  final double blinkValue;
  final bool isWinnerMode;
  final List<Offset> offsets;
  final double radiusScale;

  final Paint _glowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

  final Paint _corePaint = Paint()..style = PaintingStyle.fill;

  OptimizedLightPainter({
    required this.progress,
    required this.blinkValue,
    required this.isWinnerMode,
    required this.offsets,
    required this.radiusScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (offsets.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * radiusScale;
    final totalLights = offsets.length;
    final headPosition = progress * totalLights;

    for (int i = 0; i < totalLights; i++) {
      final opacity = _calculateOpacity(i, headPosition, totalLights);
      if (opacity < 0.05) continue;

      final targetOffset = offsets[i];
      final position = Offset(
        center.dx + (targetOffset.dx * baseRadius),
        center.dy + (targetOffset.dy * baseRadius),
      );

      final color = _getRainbowColor(i, totalLights);

      _glowPaint.color = color.withOpacity(opacity * 0.8);
      _corePaint.color = color.withOpacity(opacity);

      if (opacity > 0.1) {
        canvas.drawCircle(position, 16, _glowPaint);
      }
      canvas.drawCircle(position, 7, _corePaint);
    }
  }

  double _calculateOpacity(int index, double headPos, int total) {
    if (isWinnerMode) {
      return 0.2 + (blinkValue * 0.8);
    } else {
      double distance = (headPos - index) % total;
      if (distance < 0) distance += total;

      if (distance < 4.0) {
        return math.max(0.0, 1.0 - (distance / 4.0));
      }
      return 0.05;
    }
  }

  Color _getRainbowColor(int index, int total) {
    final hue = (index / total) * 360;
    return HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
  }

  @override
  bool shouldRepaint(covariant OptimizedLightPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.blinkValue != blinkValue ||
        oldDelegate.isWinnerMode != isWinnerMode;
  }
}
