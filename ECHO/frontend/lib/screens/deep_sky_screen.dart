import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:async';

import '../models/echo_orb.dart';
import '../widgets/orb_widget.dart';
import '../widgets/exhale_anchor.dart';
import '../utils/sound_manager.dart';
import '../utils/orb_physics_engine.dart';
import '../services/echo_api_service.dart';
import 'arrival_screen.dart';
import 'thread_view.dart';

enum EchoState { idle, focused, arrival, chatting, typing }

class DeepSkyScreen extends StatefulWidget {
  const DeepSkyScreen({super.key});

  @override
  State<DeepSkyScreen> createState() => _DeepSkyScreenState();
}

class _DeepSkyScreenState extends State<DeepSkyScreen>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late AnimationController _auroraController;
  late AnimationController _catchController;
  late AnimationController _exhaleExpandController;
  late AnimationController _implodeController;

  final List<EchoOrb> _orbs = [];
  final TextEditingController _exhaleInputController = TextEditingController();
  final OrbPhysicsEngine _physicsEngine = OrbPhysicsEngine();
  final EchoApiService _apiService = EchoApiService.instance;

  EchoOrb? _caughtOrb;
  EchoState _state = EchoState.idle;
  double _exhaleIntensity = 0.0;
  bool _isExhaleSphereExpanded = false;

  String? _currentEchoContent;
  String? _currentEchoId;
  bool _isFetching = false;
  Timer? _inboxTimer;
  List<dynamic> _threads = [];

  @override
  void initState() {
    super.initState();
    _startInboxPolling();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _catchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _exhaleExpandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _implodeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _orbs.addAll(_physicsEngine.initializeOrbs(12));
  }

  void _startInboxPolling() {
    Future.delayed(const Duration(seconds: 2), () {
      _inboxTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _fetchInbox();
      });
    });
  }

  Future<void> _fetchInbox() async {
    final data = await _apiService.fetchInbox();
    if (mounted) {
      setState(() {
        _threads = data;
      });
    }
  }

  @override
  void dispose() {
    _inboxTimer?.cancel();
    _driftController.dispose();
    _auroraController.dispose();
    _catchController.dispose();
    _exhaleExpandController.dispose();
    _implodeController.dispose();
    _exhaleInputController.dispose();
    super.dispose();
  }

  void _onCatch(EchoOrb orb) {
    if (_state != EchoState.idle) return;
    HapticFeedback.mediumImpact();
    SoundManager.playCatch();
    setState(() {
      _caughtOrb = orb;
      _state = EchoState.focused;
      _currentEchoContent = null;
    });
    _catchController.forward(from: 0);
    _fetchEcho();
  }

  void _resetToIdle() {
    if (_isExhaleSphereExpanded) {
      _exhaleExpandController.reverse().then((_) {
        if (mounted) setState(() => _isExhaleSphereExpanded = false);
      });
    }
    if (_caughtOrb != null) {
      _catchController.reverse().then((_) {
        if (mounted) setState(() => _caughtOrb = null);
      });
    }
    setState(() {
      _state = EchoState.idle;
      _exhaleIntensity = 0;
      _exhaleInputController.clear();
    });
  }

  void _onLetFade() => _resetToIdle();

  void _triggerImplosion() {
    if (_state != EchoState.typing) return;
    final message = _exhaleInputController.text.trim();
    if (message.isEmpty) {
      _resetToIdle();
      return;
    }
    HapticFeedback.heavyImpact();
    SoundManager.playExhale();

    setState(() {
      _state = EchoState.idle;
      _exhaleIntensity = 0;
      _exhaleInputController.clear();
    });

    _implodeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _isExhaleSphereExpanded = false;
        });
        _exhaleExpandController.value = 0;
        _implodeController.value = 0;
      }
    });

    _sendEcho(message);
  }

  Future<void> _sendEcho(String content) async {
    await _apiService.sendEcho(content: content);
  }

  Future<void> _fetchEcho() async {
    setState(() {
      _isFetching = true;
      _currentEchoContent = null;
    });

    final data = await _apiService.fetchRandomEcho();

    if (mounted) {
      if (data != null) {
        setState(() {
          _currentEchoContent = data['content'];
          _currentEchoId = data['id'];
          _isFetching = false;
        });
      } else {
        setState(() {
          _currentEchoContent = "The void is silent.";
          _isFetching = false;
        });
      }
    }
  }

  void _showInbox() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const Text(
          "Echoes Returning",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _threads.length,
            itemBuilder: (context, index) {
              final thread = _threads[index];
              final msgs = thread['messages'] as List;
              final firstMsg = msgs.first;
              final bool isMyEcho = firstMsg['senderId'] == _apiService.userId;

              return ListTile(
                leading: Icon(
                  isMyEcho
                      ? Icons.campaign_outlined
                      : Icons.catching_pokemon_outlined,
                  color: isMyEcho ? Colors.blueAccent : Colors.purpleAccent,
                ),
                title: Text(
                  msgs.last['content'],
                  style: const TextStyle(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  isMyEcho ? "Replies to my Echo" : "Echo I caught",
                  style: TextStyle(
                    color: isMyEcho
                        ? Colors.blue.shade200
                        : Colors.purple.shade200,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _state = EchoState.chatting;
                    _currentEchoContent = msgs.last['content'];
                  });
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _sendReply(String content) async {
    if (_currentEchoId == null) return;
    await _apiService.sendReply(
      echoId: _currentEchoId!,
      content: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: _state == EchoState.idle,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _state != EchoState.idle) _resetToIdle();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF010204),
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return Stack(
              children: [
                // Background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [
                          Color.lerp(
                            const Color(0xFF0D1B2A),
                            const Color(0xFF1B263B),
                            _exhaleIntensity,
                          )!,
                          const Color(0xFF010204),
                        ],
                      ),
                    ),
                  ),
                ),
                // Aurora
                AnimatedBuilder(
                  animation: _auroraController,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: SweepGradient(
                          center: const Alignment(0.0, 0.5),
                          colors: [
                            Colors.transparent,
                            const Color(0xFF4A148C).withValues(alpha: 0.1),
                            const Color(0xFF006064).withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                          transform: GradientRotation(
                            _auroraController.value * 2 * pi,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Dust
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _driftController,
                    _exhaleExpandController,
                    _implodeController,
                  ]),
                  builder: (context, child) {
                    final double tExp = Curves.fastOutSlowIn.transform(
                      _exhaleExpandController.value,
                    );
                    final double tDissolve = Curves.easeOutSine.transform(
                      _implodeController.value,
                    );

                    double baseAnchorY = screenSize.height - 122.5;
                    double targetAnchorY = screenSize.height / 2;
                    double currentAnchorY =
                        baseAnchorY + (targetAnchorY - baseAnchorY) * tExp;

                    if (tDissolve > 0) {
                      currentAnchorY -= 150 * tDissolve;
                    }

                    // Release the gravity well as the sphere dissolves
                    final double currentGravity =
                        _exhaleExpandController.value * (1.0 - tDissolve);

                    return CustomPaint(
                      painter: DustPainter(
                        scroll: _driftController.value,
                        gravityWellStrength: currentGravity,
                        anchorY: currentAnchorY,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
                // Constellations
                AnimatedBuilder(
                  animation: _driftController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ConstellationPainter(
                        orbs: _orbs,
                        screenSize: screenSize,
                        caughtOrb: _caughtOrb,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
                // Orbs
                AnimatedBuilder(
                  animation: _driftController,
                  builder: (context, child) {
                    _physicsEngine.updateOrbs(
                      orbs: _orbs,
                      screenSize: screenSize,
                      caughtOrb: _caughtOrb,
                      isExhaleSphereExpanded: _isExhaleSphereExpanded,
                      exhaleExpandController: _exhaleExpandController,
                      implodeController: _implodeController,
                      echoState: _state,
                    );
                    return Stack(
                      fit: StackFit.expand,
                      children: _orbs.where((o) => o != _caughtOrb).map((orb) {
                        final double depthScale = 0.6 + (orb.z * 0.4);
                        final double depthOpacity = 0.4 + (orb.z * 0.6);
                        final double depthBlur = (1.0 - orb.z) * 4.0;

                        // Create a unique pulse for each orb based on time and its properties
                        final double basePulse =
                            (sin(
                                  _driftController.value * pi * 4 +
                                      (orb.x * 10),
                                ) +
                                1) /
                            2;
                        final double pulseIntensity =
                            0.8 +
                            (0.2 *
                                basePulse); // Throbs between 0.8 and 1.0 multiplier

                        return Positioned(
                          left:
                              orb.x * screenSize.width -
                              (orb.size * depthScale / 2),
                          top:
                              orb.y * screenSize.height -
                              (orb.size * depthScale / 2),
                          child: GestureDetector(
                            onTapDown: (_) => _onCatch(orb),
                            onPanUpdate: (details) {
                              if (_state == EchoState.idle) {
                                setState(() {
                                  orb.x += details.delta.dx / screenSize.width;
                                  orb.y += details.delta.dy / screenSize.height;
                                  orb.vx = 0;
                                  orb.vy = 0;
                                });
                              }
                            },
                            onPanEnd: (details) {
                              if (_state == EchoState.idle) {
                                setState(() {
                                  orb.vx =
                                      details.velocity.pixelsPerSecond.dx /
                                      screenSize.width *
                                      0.01;
                                  orb.vy =
                                      details.velocity.pixelsPerSecond.dy /
                                      screenSize.height *
                                      0.01;
                                });
                              }
                            },
                            child: OrbWidget(
                              size: orb.size * depthScale,
                              intensity: 0.7 * depthOpacity * pulseIntensity,
                              blurSigma: depthBlur,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                // Focal Blur
                if (_state != EchoState.idle)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        if (_state == EchoState.focused ||
                            _state == EchoState.arrival) {
                          _onLetFade();
                        }
                      },
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _catchController,
                          _implodeController,
                        ]),
                        builder: (context, child) {
                          double sigma =
                              45 *
                              (_state == EchoState.typing
                                  ? 1.0
                                  : _catchController.value);
                          return BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: sigma,
                              sigmaY: sigma,
                            ),
                            child: Container(
                              color: Colors.black.withValues(
                                alpha: 0.6 * (sigma / 45),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                // Expanding Orb
                if (_caughtOrb != null)
                  AnimatedBuilder(
                    animation: _catchController,
                    builder: (context, child) {
                      final double t = Curves.fastOutSlowIn.transform(
                        _catchController.value,
                      );
                      final double size = ui.lerpDouble(
                        _caughtOrb!.size,
                        260.0,
                        t,
                      )!;
                      final double x = ui.lerpDouble(
                        _caughtOrb!.x * screenSize.width,
                        screenSize.width / 2,
                        t,
                      )!;
                      final double y = ui.lerpDouble(
                        _caughtOrb!.y * screenSize.height,
                        screenSize.height / 2,
                        t,
                      )!;
                      return Positioned(
                        left: x - size / 2,
                        top: y - size / 2,
                        child: GestureDetector(
                          onTap: () {
                            if (_state == EchoState.focused &&
                                _catchController.isCompleted) {
                              setState(() => _state = EchoState.arrival);
                            }
                          },
                          child: OrbWidget(
                            size: size,
                            intensity: 0.6 + (0.4 * t),
                          ),
                        ),
                      );
                    },
                  ),
                // Exhale Sphere
                if (_isExhaleSphereExpanded)
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _exhaleExpandController,
                      _implodeController,
                    ]),
                    builder: (context, child) {
                      final double tExp = Curves.fastOutSlowIn.transform(
                        _exhaleExpandController.value,
                      );
                      final double tDissolve = Curves.easeOutSine.transform(
                        _implodeController.value,
                      );

                      var size = ui.lerpDouble(85.0, 260.0, tExp)!;
                      if (tDissolve > 0) {
                        size = ui.lerpDouble(size, size * 1.3, tDissolve)!;
                      }

                      var y = ui.lerpDouble(
                        screenSize.height - 122.5,
                        screenSize.height / 2,
                        tExp,
                      )!;
                      if (tDissolve > 0) {
                        y -= 150 * tDissolve;
                      }

                      final double intensity =
                          (0.8 + (0.2 * tExp)) * (1.0 - tDissolve);
                      final double blur = tDissolve * 20.0;

                      return Positioned(
                        left: (screenSize.width / 2) - (size / 2),
                        top: y - (size / 2),
                        child: OrbWidget(
                          size: size,
                          intensity: intensity,
                          blurSigma: blur,
                        ),
                      );
                    },
                  ),
                // Arrival
                if (_state == EchoState.arrival)
                  ArrivalScreen(
                    message: _currentEchoContent,
                    isFetching: _isFetching,
                    onReply: () => setState(() => _state = EchoState.chatting),
                    onLetFade: _onLetFade,
                  ),
                // Chatting
                if (_state == EchoState.chatting)
                  ThreadView(
                    onLetFade: _onLetFade,
                    initialMessage: _currentEchoContent,
                    onSendReply: (text) => _sendReply(text),
                  ),
                // Typing
                if (_state == EchoState.typing)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _state = EchoState.idle;
                        _exhaleIntensity = 0;
                        _exhaleInputController.clear();
                      });
                      _exhaleExpandController.reverse().then((_) {
                        if (mounted) {
                          setState(() => _isExhaleSphereExpanded = false);
                        }
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: bottomInset > 0 ? bottomInset / 2 : 0,
                          ),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutBack,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: 0.8 + (0.2 * value),
                                child: Opacity(
                                  opacity: value.clamp(0.0, 1.0),
                                  child: child,
                                ),
                              );
                            },
                            child: GestureDetector(
                              onTap: () {},
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.2),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _exhaleInputController,
                                  autofocus: true,
                                  maxLines: null,
                                  textAlign: TextAlign.center,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _triggerImplosion(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 1.5,
                                    height: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        "whisper to the void...\n(press Enter to send)",
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      fontSize: 18,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Exhale Anchor
                if ((_state == EchoState.idle || _state == EchoState.typing) &&
                    !_isExhaleSphereExpanded)
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _implodeController,
                        builder: (context, child) {
                          final dissolveOpacity = _isExhaleSphereExpanded
                              ? 0.0
                              : 1.0;
                          return Opacity(
                            opacity: dissolveOpacity,
                            child: ExhaleAnchor(
                              onHoldStart: () {
                                if (_state == EchoState.idle) {
                                  HapticFeedback.mediumImpact();
                                  setState(
                                    () => _isExhaleSphereExpanded = true,
                                  );
                                  _exhaleExpandController.forward().then((_) {
                                    if (mounted) {
                                      setState(() => _state = EchoState.typing);
                                    }
                                  });
                                }
                              },
                              onHoldUpdate: (intensity) =>
                                  setState(() => _exhaleIntensity = intensity),
                              onRelease: () {
                                if (_state == EchoState.typing) {
                                  setState(() => _exhaleIntensity = 0);
                                } else if (_state == EchoState.idle &&
                                    _isExhaleSphereExpanded) {
                                  _exhaleExpandController.reverse().then((_) {
                                    if (mounted) {
                                      setState(
                                        () => _isExhaleSphereExpanded = false,
                                      );
                                    }
                                  });
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                // Inbox
                if (_threads.isNotEmpty && _state == EchoState.idle)
                  Positioned(
                    bottom: 40,
                    right: 30,
                    child: GestureDetector(
                      onTap: _showInbox,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_chat_unread_rounded,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class DustPainter extends CustomPainter {
  final double scroll;
  final double gravityWellStrength;
  final double anchorY;

  DustPainter({
    required this.scroll,
    this.gravityWellStrength = 0.0,
    required this.anchorY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.1);
    final random = Random(42);

    // Anchor coordinates
    final double anchorX = size.width / 2;

    for (int i = 0; i < 80; i++) {
      double x = random.nextDouble();
      double y = random.nextDouble();
      double speed = random.nextDouble() * 0.2 + 0.05;

      y -= scroll * speed * 0.2;

      // Calculate true screen coordinates for this particle
      double px = x * size.width;
      double py = ((y % 1.0 + 1.0) % 1.0) * size.height;

      // Apply Gravity Well if Exhale Anchor is expanding
      if (gravityWellStrength > 0) {
        double dx = anchorX - px;
        double dy = anchorY - py;
        // Move particle towards anchor based on strength
        px += dx * gravityWellStrength * speed * 4.0;
        py += dy * gravityWellStrength * speed * 4.0;
      }

      double opacity = (sin(i * 10 + scroll * 20) + 1) / 2 * 0.15 + 0.05;

      // Particles get brighter as they get sucked into the well
      if (gravityWellStrength > 0) {
        opacity += gravityWellStrength * 0.2;
      }

      paint.color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.drawCircle(
        Offset(px, py),
        random.nextDouble() * 1.5 +
            (gravityWellStrength * 2.0), // Grow slightly
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DustPainter oldDelegate) =>
      oldDelegate.scroll != scroll ||
      oldDelegate.gravityWellStrength != gravityWellStrength;
}

class ConstellationPainter extends CustomPainter {
  final List<EchoOrb> orbs;
  final ui.Size screenSize;
  final EchoOrb? caughtOrb;

  ConstellationPainter({
    required this.orbs,
    required this.screenSize,
    required this.caughtOrb,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (orbs.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (int i = 0; i < orbs.length; i++) {
      for (int j = i + 1; j < orbs.length; j++) {
        var o1 = orbs[i];
        var o2 = orbs[j];

        if (o1 == caughtOrb || o2 == caughtOrb) continue;
        if (o1.threadId == null || o1.threadId != o2.threadId) continue;

        double x1 = o1.x * screenSize.width;
        double y1 = o1.y * screenSize.height;
        double x2 = o2.x * screenSize.width;
        double y2 = o2.y * screenSize.height;

        double dx = x2 - x1;
        double dy = y2 - y1;
        double dist = sqrt(dx * dx + dy * dy);

        // Only draw tether if they are reasonably close
        if (dist < 200) {
          double opacity = (1.0 - (dist / 200)).clamp(0.0, 1.0) * 0.5;
          paint.color = Color.lerp(
            const Color(0xFF4FC3F7),
            const Color(0xFFB39DDB),
            o1.hue,
          )!.withValues(alpha: opacity);

          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) => true; // Needs constant repaint for physics
}
