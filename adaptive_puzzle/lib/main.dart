import 'dart:async';
import 'dart:js_interop';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Run automated CS engine test assertions
  ArcadeEngineVerifier.runAllTests();
  runApp(const AdaptivePuzzleApp());
}

@JS('localStorage.getItem')
external JSString? _jsLocalStorageGetItem(JSString key);

@JS('localStorage.setItem')
external void _jsLocalStorageSetItem(JSString key, JSString value);

class LocalStorageRepository {
  static const String _keyPoints = 'synapse_arcade_wallet_points';
  static const String _keyTheme = 'synapse_arcade_selected_theme';
  static const String _keyAudio = 'synapse_arcade_audio_enabled';

  static int loadPoints() {
    if (kIsWeb) {
      try {
        final val = _jsLocalStorageGetItem(_keyPoints.toJS);
        if (val != null) {
          return int.tryParse(val.toDart) ?? 0;
        }
      } catch (_) {}
    }
    return 0;
  }

  static void savePoints(int points) {
    if (kIsWeb) {
      try {
        _jsLocalStorageSetItem(_keyPoints.toJS, points.toString().toJS);
      } catch (_) {}
    }
  }

  static String loadTheme() {
    if (kIsWeb) {
      try {
        final val = _jsLocalStorageGetItem(_keyTheme.toJS);
        if (val != null) return val.toDart;
      } catch (_) {}
    }
    return 'Neon Cyan';
  }

  static void saveTheme(String theme) {
    if (kIsWeb) {
      try {
        _jsLocalStorageSetItem(_keyTheme.toJS, theme.toJS);
      } catch (_) {}
    }
  }

  static bool loadAudioEnabled() {
    if (kIsWeb) {
      try {
        final val = _jsLocalStorageGetItem(_keyAudio.toJS);
        if (val != null) return val.toDart == 'true';
      } catch (_) {}
    }
    return true;
  }

  static void saveAudioEnabled(bool enabled) {
    if (kIsWeb) {
      try {
        _jsLocalStorageSetItem(_keyAudio.toJS, enabled.toString().toJS);
      } catch (_) {}
    }
  }
}

@JS('eval')
external JSAny? _jsEval(String script);

class GameAudioHaptics {
  static bool soundEnabled = true;

  static void playClick() {
    if (!soundEnabled) return;
    HapticFeedback.lightImpact();
    if (kIsWeb) {
      _evalWebTone(
        frequency: 1100,
        type: 'triangle',
        durationSeconds: 0.045,
        gain: 0.06,
      );
    } else {
      SystemSound.play(SystemSoundType.click);
    }
  }

  static void playSuccessChime() {
    if (!soundEnabled) return;
    HapticFeedback.heavyImpact();
    if (kIsWeb) {
      _evalWebTone(
        frequency: 523.25,
        type: 'sine',
        durationSeconds: 0.45,
        gain: 0.12,
      );
      Future.delayed(const Duration(milliseconds: 90), () {
        _evalWebTone(
          frequency: 659.25,
          type: 'sine',
          durationSeconds: 0.45,
          gain: 0.14,
        );
      });
      Future.delayed(const Duration(milliseconds: 180), () {
        _evalWebTone(
          frequency: 783.99,
          type: 'sine',
          durationSeconds: 0.6,
          gain: 0.15,
        );
      });
    }
  }

  static void playGameOverTone() {
    if (!soundEnabled) return;
    HapticFeedback.mediumImpact();
    if (kIsWeb) {
      _evalWebTone(
        frequency: 240,
        type: 'sawtooth',
        durationSeconds: 0.35,
        gain: 0.1,
      );
    }
  }

  static void _evalWebTone({
    required double frequency,
    required String type,
    required double durationSeconds,
    required double gain,
  }) {
    try {
      final jsCode =
          '''
        (() => {
          const AudioContext = window.AudioContext || window.webkitAudioContext;
          if (!AudioContext) return;
          if (!window._gameAudioCtx) window._gameAudioCtx = new AudioContext();
          const ctx = window._gameAudioCtx;
          if (ctx.state === 'suspended') ctx.resume();
          const osc = ctx.createOscillator();
          const gainNode = ctx.createGain();
          osc.type = '$type';
          osc.frequency.setValueAtTime($frequency, ctx.currentTime);
          gainNode.gain.setValueAtTime($gain, ctx.currentTime);
          gainNode.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + $durationSeconds);
          osc.connect(gainNode);
          gainNode.connect(ctx.destination);
          osc.start();
          osc.stop(ctx.currentTime + $durationSeconds);
        })();
      ''';
      _jsEval(jsCode);
    } catch (_) {}
  }
}

class ArcadeTheme {
  final String name;
  final Color primary;
  final Color accent;
  final Color background;
  final int cost;

  const ArcadeTheme({
    required this.name,
    required this.primary,
    required this.accent,
    required this.background,
    required this.cost,
  });
}

const List<ArcadeTheme> kAvailableThemes = [
  ArcadeTheme(
    name: 'Neon Cyan',
    primary: Colors.cyanAccent,
    accent: Color(0xFF00E5FF),
    background: Color(0xFF0A0C14),
    cost: 0,
  ),
  ArcadeTheme(
    name: 'Solar Amber',
    primary: Colors.amberAccent,
    accent: Color(0xFFFF9100),
    background: Color(0xFF140F0A),
    cost: 150,
  ),
  ArcadeTheme(
    name: 'Matrix Emerald',
    primary: Colors.greenAccent,
    accent: Color(0xFF00E676),
    background: Color(0xFF0A140E),
    cost: 250,
  ),
  ArcadeTheme(
    name: 'Cyber Pink',
    primary: Colors.pinkAccent,
    accent: Color(0xFFFF4081),
    background: Color(0xFF140A12),
    cost: 350,
  ),
];

class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double radius;
  double life;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
    this.life = 1.0,
  });

  void update() {
    position += velocity;
    velocity *= 0.94;
    life -= 0.024;
  }
}

class ParticleBurstOverlay extends StatefulWidget {
  final bool trigger;
  const ParticleBurstOverlay({super.key, required this.trigger});

  @override
  State<ParticleBurstOverlay> createState() => _ParticleBurstOverlayState();
}

class _ParticleBurstOverlayState extends State<ParticleBurstOverlay>
    with SingleTickerProviderStateMixin {
  final List<Particle> _particles = [];
  final Random _rng = Random();
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1000),
        )..addListener(() {
          if (_particles.isNotEmpty) {
            setState(() {
              for (var p in _particles) {
                p.update();
              }
              _particles.removeWhere((p) => p.life <= 0);
            });
          }
        });
  }

  @override
  void didUpdateWidget(covariant ParticleBurstOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) _spawnBurst();
  }

  void _spawnBurst() {
    _particles.clear();
    final colors = [
      globalPoints.activeTheme.primary,
      globalPoints.activeTheme.accent,
      Colors.amberAccent,
      Colors.white,
    ];
    for (int i = 0; i < 65; i++) {
      double angle = _rng.nextDouble() * 2 * pi;
      double speed = _rng.nextDouble() * 6.5 + 2.0;
      _particles.add(
        Particle(
          position: Offset.zero,
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          color: colors[_rng.nextInt(colors.length)],
          radius: _rng.nextDouble() * 3.5 + 2.0,
        ),
      );
    }
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlePainter(
          particles: _particles,
          progress: _controller.value,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;
  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    if (progress > 0.0 && progress < 1.0) {
      final wavePaint = Paint()
        ..color = globalPoints.activeTheme.primary.withValues(
          alpha: (1.0 - progress) * 0.4,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.0 - progress) * 6.0;
      canvas.drawCircle(center, progress * size.width * 0.65, wavePaint);
    }
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);
      canvas.drawCircle(center + p.position, p.radius * p.life, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class AppPointsNotifier extends ChangeNotifier {
  late int points;
  late ArcadeTheme activeTheme;

  AppPointsNotifier() {
    points = LocalStorageRepository.loadPoints();
    final themeName = LocalStorageRepository.loadTheme();
    activeTheme = kAvailableThemes.firstWhere(
      (t) => t.name == themeName,
      orElse: () => kAvailableThemes.first,
    );
    GameAudioHaptics.soundEnabled = LocalStorageRepository.loadAudioEnabled();
  }

  void addPoints(int amount) {
    points += amount;
    LocalStorageRepository.savePoints(points);
    notifyListeners();
  }

  bool spendPoints(int amount) {
    if (points >= amount) {
      points -= amount;
      LocalStorageRepository.savePoints(points);
      notifyListeners();
      return true;
    }
    return false;
  }

  void setTheme(ArcadeTheme theme) {
    activeTheme = theme;
    LocalStorageRepository.saveTheme(theme.name);
    notifyListeners();
  }

  void toggleSound(bool enabled) {
    GameAudioHaptics.soundEnabled = enabled;
    LocalStorageRepository.saveAudioEnabled(enabled);
    notifyListeners();
  }

  void reset() {
    points = 0;
    LocalStorageRepository.savePoints(points);
    notifyListeners();
  }
}

final globalPoints = AppPointsNotifier();

class AdaptivePuzzleApp extends StatelessWidget {
  const AdaptivePuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: globalPoints,
      builder: (context, _) {
        return MaterialApp(
          title: 'ADAPTIVE PUZZLE',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: globalPoints.activeTheme.background,
            colorScheme: ColorScheme.dark(
              primary: globalPoints.activeTheme.primary,
              surface: globalPoints.activeTheme.background,
            ),
          ),
          home: const ArcadeHubScreen(),
        );
      },
    );
  }
}

class ArcadeHubScreen extends StatefulWidget {
  const ArcadeHubScreen({super.key});
  @override
  State<ArcadeHubScreen> createState() => _ArcadeHubScreenState();
}

class _ArcadeHubScreenState extends State<ArcadeHubScreen> {
  @override
  void initState() {
    super.initState();
    globalPoints.addListener(_onPointsChanged);
  }

  @override
  void dispose() {
    globalPoints.removeListener(_onPointsChanged);
    super.dispose();
  }

  void _onPointsChanged() => setState(() {});

  void _openStoreDialog() {
    GameAudioHaptics.playClick();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF131627),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.shopping_bag_rounded,
                  color: globalPoints.activeTheme.primary,
                ),
                const SizedBox(width: 10),
                const Text('Cyberpunk Store'),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WALLET: ${globalPoints.points} PTS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: globalPoints.activeTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'COSMETIC NODE SKINS',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...kAvailableThemes.map((t) {
                    final isSelected = globalPoints.activeTheme.name == t.name;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2038),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? t.primary : Colors.white12,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: t.primary, radius: 10),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 12,
                              ),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: t.primary.withValues(
                                  alpha: 0.2,
                                ),
                                foregroundColor: t.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () {
                                if (globalPoints.points >= t.cost) {
                                  globalPoints.spendPoints(t.cost);
                                  globalPoints.setTheme(t);
                                  setDlgState(() {});
                                } else {
                                  GameAudioHaptics.playGameOverTone();
                                }
                              },
                              child: Text(
                                t.cost == 0 ? 'Equip' : '${t.cost} Pts',
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CLOSE'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.3,
            colors: [
              globalPoints.activeTheme.primary.withValues(alpha: 0.18),
              globalPoints.activeTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        GameAudioHaptics.soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () => globalPoints.toggleSound(
                        !GameAudioHaptics.soundEnabled,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.storefront_rounded,
                        color: globalPoints.activeTheme.primary,
                      ),
                      onPressed: _openStoreDialog,
                    ),
                  ],
                ),
              ),
              const Text(
                'ADAPTIVE PUZZLE',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: globalPoints.activeTheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: globalPoints.activeTheme.primary.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: Text(
                  'GLOBAL WALLET: ${globalPoints.points} PTS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: globalPoints.activeTheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _GameModeCard(
                          title: 'Synapse Flow',
                          subtitle:
                              'Rotate circuit nodes to restore grid power',
                          icon: Icons.alt_route_rounded,
                          accentColor: const Color(0xFF00E5FF),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SynapseFlowScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _GameModeCard(
                          title: 'Digital Escape Room',
                          subtitle: '5 Escalating Chambers: Level 1 to 5',
                          icon: Icons.meeting_room_rounded,
                          accentColor: const Color(0xFFFF5252),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EscapeRoomScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _GameModeCard(
                          title: 'Block Escape',
                          subtitle:
                              'Slide blocking conduits in all directions to unseal the prime core',
                          icon: Icons.view_compact_alt_rounded,
                          accentColor: const Color(0xFFFF9100),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BlockEscapeScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _GameModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _GameModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121526),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            GameAudioHaptics.playClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: accentColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum Direction { up, right, down, left }

class NodeTile {
  final int x, y;
  int connections;
  int rotation;
  bool isSource, isTarget, isPowered;

  NodeTile({
    required this.x,
    required this.y,
    required this.connections,
    this.rotation = 0,
    this.isSource = false,
    this.isTarget = false,
    this.isPowered = false,
  });

  int get currentConnections {
    int mask = 0;
    for (int i = 0; i < 4; i++) {
      if ((connections & (1 << i)) != 0) {
        mask |= (1 << ((i + rotation) % 4));
      }
    }
    return mask;
  }

  bool connectsTo(Direction dir) =>
      (currentConnections & (1 << dir.index)) != 0;

  void rotate() => rotation = (rotation + 1) % 4;
}

class SynapseEngine {
  static final Random _rng = Random();

  static List<List<NodeTile>> generate(int size) {
    List<List<NodeTile>> grid = List.generate(
      size,
      (y) => List.generate(size, (x) => NodeTile(x: x, y: y, connections: 0)),
    );
    List<List<bool>> visited = List.generate(
      size,
      (_) => List.filled(size, false),
    );
    List<Point<int>> stack = [];

    int startX = _rng.nextInt(size);
    int startY = _rng.nextInt(size);
    visited[startY][startX] = true;
    grid[startY][startX].isSource = true;
    stack.add(Point(startX, startY));

    final dirs = [
      {'dx': 0, 'dy': -1, 'dir': 0, 'opp': 2},
      {'dx': 1, 'dy': 0, 'dir': 1, 'opp': 3},
      {'dx': 0, 'dy': 1, 'dir': 2, 'opp': 0},
      {'dx': -1, 'dy': 0, 'dir': 3, 'opp': 1},
    ];

    while (stack.isNotEmpty) {
      Point<int> curr = stack.last;
      var neighbors = <Map<String, int>>[];
      for (var d in dirs) {
        int nx = curr.x + d['dx']!;
        int ny = curr.y + d['dy']!;
        if (nx >= 0 && nx < size && ny >= 0 && ny < size && !visited[ny][nx]) {
          neighbors.add({'x': nx, 'y': ny, ...d});
        }
      }
      if (neighbors.isNotEmpty) {
        var chosen = neighbors[_rng.nextInt(neighbors.length)];
        int nx = chosen['x']!;
        int ny = chosen['y']!;
        grid[curr.y][curr.x].connections |= (1 << chosen['dir']!);
        grid[ny][nx].connections |= (1 << chosen['opp']!);
        visited[ny][nx] = true;
        stack.add(Point(nx, ny));
      } else {
        stack.removeLast();
      }
    }

    grid[size - 1 - startY][size - 1 - startX].isTarget = true;
    for (var r in grid) {
      for (var t in r) {
        t.rotation = _rng.nextInt(4);
      }
    }
    evaluate(grid, size);
    return grid;
  }

  static void evaluate(List<List<NodeTile>> grid, int size) {
    for (var r in grid) {
      for (var t in r) {
        t.isPowered = false;
      }
    }
    NodeTile? source;
    for (var r in grid) {
      for (var t in r) {
        if (t.isSource) source = t;
      }
    }
    if (source == null) return;

    List<NodeTile> queue = [source];
    source.isPowered = true;
    List<List<bool>> visited = List.generate(
      size,
      (_) => List.filled(size, false),
    );
    visited[source.y][source.x] = true;

    final dirs = [
      {'dx': 0, 'dy': -1, 'dir': Direction.up, 'opp': Direction.down},
      {'dx': 1, 'dy': 0, 'dir': Direction.right, 'opp': Direction.left},
      {'dx': 0, 'dy': 1, 'dir': Direction.down, 'opp': Direction.up},
      {'dx': -1, 'dy': 0, 'dir': Direction.left, 'opp': Direction.right},
    ];

    while (queue.isNotEmpty) {
      NodeTile curr = queue.removeAt(0);
      for (var d in dirs) {
        int nx = curr.x + (d['dx'] as int);
        int ny = curr.y + (d['dy'] as int);
        if (nx >= 0 && nx < size && ny >= 0 && ny < size && !visited[ny][nx]) {
          NodeTile neighbor = grid[ny][nx];
          if (curr.connectsTo(d['dir'] as Direction) &&
              neighbor.connectsTo(d['opp'] as Direction)) {
            neighbor.isPowered = true;
            visited[ny][nx] = true;
            queue.add(neighbor);
          }
        }
      }
    }
  }

  static bool isComplete(List<List<NodeTile>> grid) {
    for (var r in grid) {
      for (var t in r) {
        if (!t.isPowered) return false;
      }
    }
    return true;
  }
}

class SynapseFlowScreen extends StatefulWidget {
  const SynapseFlowScreen({super.key});

  @override
  State<SynapseFlowScreen> createState() => _SynapseFlowScreenState();
}

class _SynapseFlowScreenState extends State<SynapseFlowScreen> {
  int _gridSize = 3;
  int _stage = 1;
  late int _movesLeft;
  bool _isSolved = false;
  bool _isGameOver = false;
  late List<List<NodeTile>> _grid;

  @override
  void initState() {
    super.initState();
    _startStage();
  }

  void _startStage() {
    setState(() {
      _isSolved = false;
      _isGameOver = false;
      _movesLeft = 18 + (_stage - 1) * 50;
      _grid = SynapseEngine.generate(_gridSize);
    });
  }

  void _usePowerUpAutoAlign() {
    if (_isSolved || _isGameOver) return;
    if (!globalPoints.spendPoints(25)) {
      GameAudioHaptics.playGameOverTone();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need 25 Points for Auto-Align!')),
      );
      return;
    }
    GameAudioHaptics.playClick();
    for (var r in _grid) {
      for (var t in r) {
        if (!t.isPowered) {
          for (int i = 0; i < 4; i++) {
            t.rotate();
            SynapseEngine.evaluate(_grid, _gridSize);
            if (t.isPowered) break;
          }
          setState(() {
            _isSolved = SynapseEngine.isComplete(_grid);
          });
          return;
        }
      }
    }
  }

  void _onTileTapped(int x, int y) {
    if (_isSolved || _isGameOver) return;
    GameAudioHaptics.playClick();
    setState(() {
      _grid[y][x].rotate();
      _movesLeft--;
      SynapseEngine.evaluate(_grid, _gridSize);
      _isSolved = SynapseEngine.isComplete(_grid);
      if (!_isSolved && _movesLeft <= 0) {
        _isGameOver = true;
        GameAudioHaptics.playGameOverTone();
      }
    });

    if (_isSolved) {
      GameAudioHaptics.playSuccessChime();
      globalPoints.addPoints(50);
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _stage++;
          if (globalPoints.points >= 200) {
            _gridSize = 5;
          } else if (globalPoints.points >= 100) {
            _gridSize = 4;
          }
          _startStage();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: 'Synapse Flow',
      stage: _stage,
      movesLeft: _movesLeft,
      isSolved: _isSolved,
      isGameOver: _isGameOver,
      onRestart: _startStage,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111422),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _isSolved
                      ? globalPoints.activeTheme.primary
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridSize,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _gridSize * _gridSize,
                itemBuilder: (context, index) {
                  int x = index % _gridSize;
                  int y = index ~/ _gridSize;
                  NodeTile tile = _grid[y][x];
                  return GestureDetector(
                    onTap: () => _onTileTapped(x, y),
                    child: AnimatedRotation(
                      turns: tile.rotation * 0.25,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: CustomPaint(
                        painter: GlowingTilePainter(tile: tile),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: globalPoints.activeTheme.primary.withValues(
                alpha: 0.15,
              ),
              foregroundColor: globalPoints.activeTheme.primary,
            ),
            onPressed: _usePowerUpAutoAlign,
            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: const Text('Auto-Align (25 Pts)'),
          ),
        ],
      ),
    );
  }
}

class EscapeRoomScreen extends StatefulWidget {
  const EscapeRoomScreen({super.key});

  @override
  State<EscapeRoomScreen> createState() => _EscapeRoomScreenState();
}

class _EscapeRoomScreenState extends State<EscapeRoomScreen> {
  int _currentRoomIndex = 0;
  int _secondsLeft = 120;
  Timer? _countdownTimer;

  bool _puzzle1Solved = false;
  bool _puzzle2Solved = false;
  bool _hasKeycard = false;
  bool _foundClue1 = false;
  bool _foundClue2 = false;
  bool _escaped = false;
  bool _isGameOver = false;

  String _pinInput = '';

  final List<Map<String, dynamic>> _rooms = [
    {
      'level': 1,
      'name': 'Level 1: Cryo Labs',
      'timeLimit': 120,
      'code': '7394',
      'clue1': 'Prefix: 73..',
      'clue2': 'Suffix: ..94',
      'p1Title': 'Cryo Vent',
      'p1Desc': 'Alternate polarity (+ / − / + / −)',
      'p1Icon': Icons.ac_unit_rounded,
      'p1Color': Colors.cyanAccent,
      'p1Size': 4,
      'p1Pattern': [true, false, true, false],
      'p2Title': 'Wall Locker',
      'p2Desc': 'Dial sum must equal 12',
      'p2TargetSum': 12,
      'p2DialCount': 2,
      'p2Icon': Icons.lock_clock_rounded,
      'p2Color': Colors.amberAccent,
      'bpTitle': 'Floor Blueprint',
      'bpDesc': 'Inspect structural drawing',
      'bpText':
          'A torn blueprint with grease stains: "Airlock Override Suffix: [ 9 4 ]"',
    },
    {
      'level': 2,
      'name': 'Level 2: Reactor Core',
      'timeLimit': 105,
      'code': '4826',
      'clue1': 'Prefix: 48..',
      'clue2': 'Suffix: ..26',
      'p1Title': 'Coolant Grid',
      'p1Desc': 'All positive (+ / + / + / + / +)',
      'p1Icon': Icons.water_drop_rounded,
      'p1Color': Colors.tealAccent,
      'p1Size': 5,
      'p1Pattern': [true, true, true, true, true],
      'p2Title': 'Pressure Valve',
      'p2Desc': '3 Dials must sum to 17',
      'p2TargetSum': 17,
      'p2DialCount': 3,
      'p2Icon': Icons.speed_rounded,
      'p2Color': Colors.orangeAccent,
      'bpTitle': 'Core Monitor',
      'bpDesc': 'Examine terminal log',
      'bpText': 'Telemetry diagnostics log: "Scram Sequence Suffix: [ 2 6 ]"',
    },
    {
      'level': 3,
      'name': 'Level 3: Cybernetics Bay',
      'timeLimit': 90,
      'code': '6158',
      'clue1': 'Prefix: 61..',
      'clue2': 'Suffix: ..58',
      'p1Title': 'Neural Synapse',
      'p1Desc': 'Mirrored charges (+ / − / − / +)',
      'p1Icon': Icons.psychology_rounded,
      'p1Color': Colors.deepPurpleAccent,
      'p1Size': 4,
      'p1Pattern': [true, false, false, true],
      'p2Title': 'Bionic Cache',
      'p2Desc': '3 Dials must sum to 21',
      'p2TargetSum': 21,
      'p2DialCount': 3,
      'p2Icon': Icons.memory_rounded,
      'p2Color': Colors.pinkAccent,
      'bpTitle': 'Data Slate',
      'bpDesc': 'Read encrypted memory file',
      'bpText': 'A recovery disk reads: "Sector 3 Access Key ends in [ 5 8 ]"',
    },
    {
      'level': 4,
      'name': 'Level 4: Bio-Containment',
      'timeLimit': 75,
      'code': '9247',
      'clue1': 'Prefix: 92..',
      'clue2': 'Suffix: ..47',
      'p1Title': 'Bio-Stabilizer',
      'p1Desc': 'Alternating twin pairs (+ / + / − / − / + / +)',
      'p1Icon': Icons.biotech_rounded,
      'p1Color': Colors.limeAccent,
      'p1Size': 6,
      'p1Pattern': [true, true, false, false, true, true],
      'p2Title': 'Specimen Vault',
      'p2Desc': '4 Dials must sum to 26',
      'p2TargetSum': 26,
      'p2DialCount': 4,
      'p2Icon': Icons.shield_rounded,
      'p2Color': Colors.lightGreenAccent,
      'bpTitle': 'Specimen Manifest',
      'bpDesc': 'Check clearance dossier',
      'bpText':
          'Hazard Warning: "Quarantine lift authorized with terminal suffix [ 4 7 ]"',
    },
    {
      'level': 5,
      'name': 'Level 5: AI Core Nexus',
      'timeLimit': 60,
      'code': '3589',
      'clue1': 'Prefix: 35..',
      'clue2': 'Suffix: ..89',
      'p1Title': 'Quantum Gate',
      'p1Desc': 'Strict parity invert (− / + / − / + / − / +)',
      'p1Icon': Icons.hub_rounded,
      'p1Color': Colors.deepOrangeAccent,
      'p1Size': 6,
      'p1Pattern': [false, true, false, true, false, true],
      'p2Title': 'Apex Firewall',
      'p2Desc': '4 Dials must sum to 31',
      'p2TargetSum': 31,
      'p2DialCount': 4,
      'p2Icon': Icons.security_rounded,
      'p2Color': Colors.redAccent,
      'bpTitle': 'Core Kernel Log',
      'bpDesc': 'Inspect root master override',
      'bpText':
          'Master AI kernel crashdump: "Root override hash terminal suffix: [ 8 9 ]"',
    },
  ];

  Map<String, dynamic> get _currentRoom => _rooms[_currentRoomIndex];

  @override
  void initState() {
    super.initState();
    _startRoom();
  }

  void _startRoom() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsLeft = _currentRoom['timeLimit'];
      _isGameOver = false;
      _escaped = false;
      _puzzle1Solved = false;
      _puzzle2Solved = false;
      _hasKeycard = false;
      _foundClue1 = false;
      _foundClue2 = false;
      _pinInput = '';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _isGameOver = true;
        });
        GameAudioHaptics.playGameOverTone();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _nextRoom() {
    setState(() {
      _currentRoomIndex = (_currentRoomIndex + 1) % _rooms.length;
      _startRoom();
    });
  }

  void _usePowerUpAddTime() {
    if (_escaped || _isGameOver) return;
    if (!globalPoints.spendPoints(40)) {
      GameAudioHaptics.playGameOverTone();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need 40 Points for Time Extension!')),
      );
      return;
    }
    GameAudioHaptics.playClick();
    setState(() {
      _secondsLeft += 30;
    });
  }

  void _showHint() {
    GameAudioHaptics.playClick();
    String hint;
    if (!_puzzle1Solved) {
      hint =
          'HINT: Solve the ${_currentRoom['p1Title']}. Target: ${_currentRoom['p1Desc']}.';
    } else if (!_puzzle2Solved) {
      hint =
          'HINT: Balance the ${_currentRoom['p2Title']} dials so their total equals ${_currentRoom['p2TargetSum']}.';
    } else if (!_hasKeycard) {
      hint =
          'HINT: Open the unlocked secondary cache to secure the security keycard.';
    } else {
      hint =
          'HINT: Put together your clues to form the 4-digit airlock PIN: ${_currentRoom['code']}.';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161928),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb_rounded, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('Room Synthesizer Hint'),
          ],
        ),
        content: Text(hint, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'UNDERSTOOD',
              style: TextStyle(color: globalPoints.activeTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _openPuzzle1() {
    GameAudioHaptics.playClick();
    List<bool> targetPattern = List<bool>.from(_currentRoom['p1Pattern']);
    int size = _currentRoom['p1Size'];
    List<bool> switches = List.generate(
      size,
      (i) => i % 2 == 0 ? !targetPattern[i] : targetPattern[i],
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          bool isCorrect = true;
          for (int i = 0; i < size; i++) {
            if (switches[i] != targetPattern[i]) {
              isCorrect = false;
              break;
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF121422),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(_currentRoom['p1Title']),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentRoom['p1Desc'],
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: List.generate(size, (i) {
                    return GestureDetector(
                      onTap: () {
                        GameAudioHaptics.playClick();
                        setDlgState(() => switches[i] = !switches[i]);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: switches[i]
                              ? globalPoints.activeTheme.primary
                              : Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          switches[i] ? '+' : '−',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 18),
                if (isCorrect)
                  const Text(
                    '⚡ RELAY ALIGNED! COMPARTMENT OPENED',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (isCorrect) {
                    GameAudioHaptics.playSuccessChime();
                    setState(() {
                      _puzzle1Solved = true;
                      _foundClue1 = true;
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: Text(
                  isCorrect ? 'GRAB CLUE' : 'DISMISS',
                  style: TextStyle(
                    color: isCorrect
                        ? globalPoints.activeTheme.primary
                        : Colors.white54,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openPuzzle2() {
    GameAudioHaptics.playClick();
    int dialCount = _currentRoom['p2DialCount'];
    int targetSum = _currentRoom['p2TargetSum'];
    List<int> dials = List.generate(dialCount, (i) => (i + 1) * 2 % 10);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          int currentSum = dials.fold(0, (acc, val) => acc + val);
          bool isUnlocked = currentSum == targetSum;

          return AlertDialog(
            backgroundColor: const Color(0xFF151829),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(_currentRoom['p2Title']),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$dialCount dials must sum to exactly $targetSum.',
                  style: const TextStyle(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: List.generate(dialCount, (i) {
                    return _buildDialWidget(
                      value: dials[i],
                      onInc: () {
                        GameAudioHaptics.playClick();
                        setDlgState(() => dials[i] = (dials[i] + 1) % 10);
                      },
                      onDec: () {
                        GameAudioHaptics.playClick();
                        setDlgState(() => dials[i] = (dials[i] - 1 + 10) % 10);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 14),
                Text(
                  'Current Sum: $currentSum / $targetSum',
                  style: TextStyle(
                    color: isUnlocked ? Colors.greenAccent : Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (isUnlocked) {
                    GameAudioHaptics.playSuccessChime();
                    setState(() {
                      _puzzle2Solved = true;
                      _hasKeycard = true;
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: Text(
                  isUnlocked ? 'RETRIEVE KEYCARD' : 'CANCEL',
                  style: TextStyle(
                    color: isUnlocked ? Colors.greenAccent : Colors.white54,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialWidget({
    required int value,
    required VoidCallback onInc,
    required VoidCallback onDec,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_drop_up_rounded, size: 32),
          onPressed: onInc,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF222842),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 32),
          onPressed: onDec,
        ),
      ],
    );
  }

  void _openTerminal() {
    GameAudioHaptics.playClick();
    String correctCode = _currentRoom['code'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF10131F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Row(
              children: [
                Icon(
                  _hasKeycard
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  color: _hasKeycard ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 8),
                const Text('Escape Airlock'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_hasKeycard)
                  const Text(
                    'SECURITY LOCKOUT: Keycard insertion required prior to passcode entry.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  )
                else ...[
                  const Text(
                    'KEYCARD VALIDATED. Enter 4-digit airlock passkey:',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: globalPoints.activeTheme.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _pinInput.padRight(4, '_').split('').join(' '),
                        style: TextStyle(
                          fontSize: 28,
                          letterSpacing: 6,
                          fontWeight: FontWeight.bold,
                          color: globalPoints.activeTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (int i = 1; i <= 9; i++)
                        _pinBtn('$i', () {
                          if (_pinInput.length < 4) {
                            GameAudioHaptics.playClick();
                            setDlgState(() => _pinInput += '$i');
                          }
                        }),
                      _pinBtn('C', () {
                        GameAudioHaptics.playClick();
                        setDlgState(() => _pinInput = '');
                      }, color: Colors.orangeAccent),
                      _pinBtn('0', () {
                        if (_pinInput.length < 4) {
                          GameAudioHaptics.playClick();
                          setDlgState(() => _pinInput += '0');
                        }
                      }),
                      _pinBtn('OK', () {
                        if (_pinInput == correctCode) {
                          Navigator.pop(ctx);
                          _handleEscapeSuccess();
                        } else {
                          GameAudioHaptics.playGameOverTone();
                          setDlgState(() => _pinInput = '');
                        }
                      }, color: Colors.greenAccent),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'DISMISS',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pinBtn(String txt, VoidCallback onTap, {Color color = Colors.white}) {
    return SizedBox(
      width: 58,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E2238),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
        onPressed: onTap,
        child: Text(
          txt,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _handleEscapeSuccess() {
    _countdownTimer?.cancel();
    GameAudioHaptics.playSuccessChime();
    globalPoints.addPoints(100);
    setState(() {
      _escaped = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentRoom['name'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Colors.amberAccent,
            ),
            tooltip: 'Request Hint',
            onPressed: _showHint,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Restart Room',
            onPressed: _startRoom,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatBadge(
                      label: 'Time Left',
                      value:
                          '${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                      color: _secondsLeft <= 20
                          ? Colors.redAccent
                          : globalPoints.activeTheme.primary,
                    ),
                    _StatBadge(
                      label: 'Chamber',
                      value: 'LVL ${_currentRoom['level']} / 5',
                    ),
                    _StatBadge(
                      label: 'Security Card',
                      value: _hasKeycard ? 'READY' : 'LOCKED',
                      color: _hasKeycard
                          ? Colors.greenAccent
                          : Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Expanded(
              flex: 10,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 460,
                      maxHeight: 520,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111422),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: _escaped
                                  ? Colors.greenAccent
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: [
                              _RoomInteractableCard(
                                title: _currentRoom['p1Title'],
                                subtitle: _puzzle1Solved
                                    ? 'Aligned • Clue 1 logged'
                                    : _currentRoom['p1Desc'],
                                icon: _puzzle1Solved
                                    ? Icons.lock_open_rounded
                                    : _currentRoom['p1Icon'],
                                color: _puzzle1Solved
                                    ? Colors.tealAccent
                                    : _currentRoom['p1Color'],
                                onTap: _openPuzzle1,
                              ),
                              _RoomInteractableCard(
                                title: _currentRoom['p2Title'],
                                subtitle: _puzzle2Solved
                                    ? 'Keycard extracted'
                                    : _currentRoom['p2Desc'],
                                icon: _puzzle2Solved
                                    ? Icons.vpn_key_rounded
                                    : _currentRoom['p2Icon'],
                                color: _puzzle2Solved
                                    ? Colors.greenAccent
                                    : _currentRoom['p2Color'],
                                onTap: _openPuzzle2,
                              ),
                              _RoomInteractableCard(
                                title: _currentRoom['bpTitle'],
                                subtitle: _foundClue2
                                    ? 'Clue 2 logged'
                                    : _currentRoom['bpDesc'],
                                icon: Icons.description_rounded,
                                color: Colors.purpleAccent,
                                onTap: () {
                                  GameAudioHaptics.playClick();
                                  setState(() => _foundClue2 = true);
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF161928),
                                      title: Text(_currentRoom['bpTitle']),
                                      content: Text(
                                        _currentRoom['bpText'],
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('DISMISS'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              _RoomInteractableCard(
                                title: 'Escape Airlock',
                                subtitle: _hasKeycard
                                    ? 'Ready for passcode'
                                    : 'Access Restricted',
                                icon: Icons.sensor_door_rounded,
                                color: Colors.redAccent,
                                onTap: _openTerminal,
                              ),
                            ],
                          ),
                        ),

                        ParticleBurstOverlay(trigger: _escaped),

                        // Inventory Footer
                        Positioned(
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'EVIDENCE: ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),
                                Text(
                                  _foundClue1
                                      ? '[${_currentRoom['clue1']}] '
                                      : '[???] ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: globalPoints.activeTheme.primary,
                                  ),
                                ),
                                Text(
                                  _foundClue2
                                      ? '[${_currentRoom['clue2']}]'
                                      : '[???]',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.purpleAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_isGameOver)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'CONTAINMENT BREACH FAILED',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Timer depleted before clearing chamber.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _startRoom,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),

                        if (_escaped)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F2218),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.greenAccent),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'LEVEL ${_currentRoom['level']} CLEARED',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.greenAccent,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Chamber ${_currentRoom['level']} Bypassed! +100 Global Pts',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.greenAccent,
                                    foregroundColor: Colors.black,
                                  ),
                                  onPressed: _nextRoom,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: Text(
                                    _currentRoomIndex + 1 < _rooms.length
                                        ? 'Proceed to Level ${_currentRoomIndex + 2}'
                                        : 'Victory! Replay Campaign',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent.withValues(alpha: 0.15),
                foregroundColor: Colors.amberAccent,
              ),
              onPressed: _usePowerUpAddTime,
              icon: const Icon(Icons.more_time_rounded, size: 18),
              label: const Text('+30s Override (40 Pts)'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _RoomInteractableCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoomInteractableCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171B2D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EscapeBlock {
  int x, y;
  final int length;
  final bool isHorizontal;
  final bool isTarget;
  final Color color;

  EscapeBlock({
    required this.x,
    required this.y,
    required this.length,
    required this.isHorizontal,
    this.isTarget = false,
    required this.color,
  });

  EscapeBlock copy() => EscapeBlock(
    x: x,
    y: y,
    length: length,
    isHorizontal: isHorizontal,
    isTarget: isTarget,
    color: color,
  );

  int get width => isHorizontal ? length : 1;
  int get height => isHorizontal ? 1 : length;
}

class BlockEscapeScreen extends StatefulWidget {
  const BlockEscapeScreen({super.key});

  @override
  State<BlockEscapeScreen> createState() => _BlockEscapeScreenState();
}

class _BlockEscapeScreenState extends State<BlockEscapeScreen> {
  static const int _gridSize = 6;
  static const int _exitRow = 2;

  int _stage = 1;
  late int _movesLeft;
  bool _isSolved = false;
  bool _isGameOver = false;

  late List<EscapeBlock> _blocks;
  EscapeBlock? _selectedBlock;
  double _dragAccumulatorX = 0.0;
  double _dragAccumulatorY = 0.0;

  final List<List<EscapeBlock>> _presetStages = [
    // Stage 1
    [
      EscapeBlock(
        x: 1,
        y: 2,
        length: 2,
        isHorizontal: true,
        isTarget: true,
        color: const Color(0xFFFF9100),
      ),
      EscapeBlock(
        x: 3,
        y: 1,
        length: 3,
        isHorizontal: false,
        color: const Color(0xFF00E5FF),
      ),
      EscapeBlock(
        x: 0,
        y: 0,
        length: 2,
        isHorizontal: true,
        color: const Color(0xFF7C4DFF),
      ),
      EscapeBlock(
        x: 2,
        y: 0,
        length: 2,
        isHorizontal: false,
        color: const Color(0xFF69F0AE),
      ),
      EscapeBlock(
        x: 0,
        y: 3,
        length: 2,
        isHorizontal: false,
        color: const Color(0xFFFF5252),
      ),
      EscapeBlock(
        x: 1,
        y: 4,
        length: 3,
        isHorizontal: true,
        color: const Color(0xFFE040FB),
      ),
      EscapeBlock(
        x: 4,
        y: 3,
        length: 2,
        isHorizontal: false,
        color: const Color(0xFFFFD740),
      ),
    ],
    // Stage 2
    [
      EscapeBlock(
        x: 0,
        y: 2,
        length: 2,
        isHorizontal: true,
        isTarget: true,
        color: const Color(0xFFFF9100),
      ),
      EscapeBlock(
        x: 2,
        y: 1,
        length: 3,
        isHorizontal: false,
        color: const Color(0xFF00E5FF),
      ),
      EscapeBlock(
        x: 3,
        y: 0,
        length: 3,
        isHorizontal: true,
        color: const Color(0xFF7C4DFF),
      ),
      EscapeBlock(
        x: 4,
        y: 1,
        length: 2,
        isHorizontal: false,
        color: const Color(0xFF69F0AE),
      ),
      EscapeBlock(
        x: 3,
        y: 3,
        length: 2,
        isHorizontal: false,
        color: const Color(0xFFFF5252),
      ),
      EscapeBlock(
        x: 0,
        y: 4,
        length: 3,
        isHorizontal: true,
        color: const Color(0xFFE040FB),
      ),
      EscapeBlock(
        x: 4,
        y: 4,
        length: 2,
        isHorizontal: true,
        color: const Color(0xFFFFD740),
      ),
      EscapeBlock(
        x: 5,
        y: 1,
        length: 3,
        isHorizontal: false,
        color: const Color(0xFF40C4FF),
      ),
    ],
    // Stage 3
    [
      EscapeBlock(
        x: 1,
        y: 2,
        length: 2,
        isHorizontal: true,
        isTarget: true,
        color: const Color(0xFFFF9100),
      ),
      EscapeBlock(
        x: 0,
        y: 0,
        length: 3,
        isHorizontal: false,
        color: const Color(0xFF00E5FF),
      ),
      EscapeBlock(
        x: 1,
        y: 0,
        length: 2,
        isHorizontal: true,
        color: const Color(0xFF7C4DFF),
      ),
      EscapeBlock(
        x: 3,
        y: 1,
        length: 3,
        isHorizontal: false,
        color: const Color(0xFF69F0AE),
      ),
      EscapeBlock(
        x: 4,
        y: 2,
        length: 2,
        isHorizontal: false,
        color: const Color(0xFFFF5252),
      ),
      EscapeBlock(
        x: 1,
        y: 3,
        length: 2,
        isHorizontal: true,
        color: const Color(0xFFE040FB),
      ),
      EscapeBlock(
        x: 2,
        y: 4,
        length: 2,
        isHorizontal: false,
        color: const Color(0xFFFFD740),
      ),
      EscapeBlock(
        x: 3,
        y: 5,
        length: 3,
        isHorizontal: true,
        color: const Color(0xFF40C4FF),
      ),
      EscapeBlock(
        x: 5,
        y: 3,
        length: 2,
        isHorizontal: false,
        color: const Color(0xFFB2FF59),
      ),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _startStage();
  }

  void _startStage() {
    setState(() {
      _isSolved = false;
      _isGameOver = false;
      _selectedBlock = null;
      _dragAccumulatorX = 0.0;
      _dragAccumulatorY = 0.0;
      _movesLeft = 24 + (_stage - 1) * 10;

      final stageIdx = (_stage - 1) % _presetStages.length;
      _blocks = _presetStages[stageIdx].map((b) => b.copy()).toList();
      _selectedBlock = _blocks.firstWhere((b) => b.isTarget);
    });
  }

  bool _isAreaClear(
    int startX,
    int startY,
    int w,
    int h,
    EscapeBlock ignoreBlock,
  ) {
    if (startX < 0 ||
        startY < 0 ||
        startX + w > _gridSize ||
        startY + h > _gridSize) {
      return false;
    }

    for (var b in _blocks) {
      if (b == ignoreBlock) continue;
      bool overlap =
          !(startX + w <= b.x ||
              startX >= b.x + b.width ||
              startY + h <= b.y ||
              startY >= b.y + b.height);
      if (overlap) return false;
    }
    return true;
  }

  bool _canMoveSelected(int dx, int dy) {
    if (_selectedBlock == null || _isSolved || _isGameOver) return false;
    final b = _selectedBlock!;
    return _isAreaClear(b.x + dx, b.y + dy, b.width, b.height, b);
  }

  void _moveSelected(int dx, int dy) {
    if (!_canMoveSelected(dx, dy)) return;
    final b = _selectedBlock!;

    GameAudioHaptics.playClick();
    setState(() {
      b.x += dx;
      b.y += dy;
      _movesLeft--;
      _checkWinCondition();
    });
  }

  void _usePowerUpShiftCore() {
    if (_isSolved || _isGameOver) return;
    final target = _blocks.firstWhere((b) => b.isTarget);
    if (!_isAreaClear(
      target.x + 1,
      target.y,
      target.width,
      target.height,
      target,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Forward path blocked! Clear ahead first.'),
        ),
      );
      return;
    }
    if (!globalPoints.spendPoints(35)) {
      GameAudioHaptics.playGameOverTone();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need 35 Points for Core Warp!')),
      );
      return;
    }
    GameAudioHaptics.playClick();
    setState(() {
      target.x += 1;
      _checkWinCondition();
    });
  }

  void _checkWinCondition() {
    final target = _blocks.firstWhere((b) => b.isTarget);
    if (target.y == _exitRow && target.x + target.width == _gridSize) {
      _isSolved = true;
      GameAudioHaptics.playSuccessChime();
      globalPoints.addPoints(60);
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _stage++;
          _startStage();
        });
      });
    } else if (_movesLeft <= 0) {
      _isGameOver = true;
      GameAudioHaptics.playGameOverTone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GameScaffold(
      title: 'Block Escape',
      stage: _stage,
      movesLeft: _movesLeft,
      isSolved: _isSolved,
      isGameOver: _isGameOver,
      onRestart: _startStage,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111422),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _isSolved
                        ? Colors.orangeAccent
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellSize = (constraints.maxWidth - 24) / _gridSize;

                    return Stack(
                      children: [
                        // Grid background
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C0E18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _gridSize,
                                  ),
                              itemCount: _gridSize * _gridSize,
                              itemBuilder: (context, idx) {
                                int x = idx % _gridSize;
                                int y = idx ~/ _gridSize;
                                bool isExitZone =
                                    (y == _exitRow && x == _gridSize - 1);
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isExitZone
                                          ? Colors.orangeAccent.withValues(
                                              alpha: 0.4,
                                            )
                                          : Colors.white.withValues(
                                              alpha: 0.03,
                                            ),
                                    ),
                                    color: isExitZone
                                        ? Colors.orangeAccent.withValues(
                                            alpha: 0.08,
                                          )
                                        : Colors.transparent,
                                  ),
                                  child: isExitZone
                                      ? const Center(
                                          child: Icon(
                                            Icons.output_rounded,
                                            size: 18,
                                            color: Colors.orangeAccent,
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                          ),
                        ),

                        // Exit indicator marker
                        Positioned(
                          right: 0,
                          top: 12 + _exitRow * cellSize,
                          width: 12,
                          height: cellSize,
                          child: Center(
                            child: Container(
                              width: 4,
                              height: cellSize * 0.7,
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orangeAccent.withValues(
                                      alpha: 0.8,
                                    ),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 4-Directional Blocks
                        ..._blocks.map((b) {
                          final isSelected = b == _selectedBlock;
                          final left = 12 + b.x * cellSize;
                          final top = 12 + b.y * cellSize;
                          final width = b.width * cellSize;
                          final height = b.height * cellSize;

                          return Positioned(
                            left: left,
                            top: top,
                            width: width,
                            height: height,
                            child: GestureDetector(
                              onTap: () {
                                GameAudioHaptics.playClick();
                                setState(() {
                                  _selectedBlock = b;
                                });
                              },
                              onPanStart: (_) {
                                _selectedBlock = b;
                                _dragAccumulatorX = 0.0;
                                _dragAccumulatorY = 0.0;
                              },
                              onPanUpdate: (details) {
                                if (_selectedBlock != b) return;
                                _dragAccumulatorX += details.delta.dx;
                                _dragAccumulatorY += details.delta.dy;

                                if (_dragAccumulatorX.abs() >=
                                        cellSize * 0.45 &&
                                    _dragAccumulatorX.abs() >
                                        _dragAccumulatorY.abs()) {
                                  if (_dragAccumulatorX > 0) {
                                    _moveSelected(1, 0);
                                  } else {
                                    _moveSelected(-1, 0);
                                  }
                                  _dragAccumulatorX = 0.0;
                                  _dragAccumulatorY = 0.0;
                                } else if (_dragAccumulatorY.abs() >=
                                        cellSize * 0.45 &&
                                    _dragAccumulatorY.abs() >
                                        _dragAccumulatorX.abs()) {
                                  if (_dragAccumulatorY > 0) {
                                    _moveSelected(0, 1);
                                  } else {
                                    _moveSelected(0, -1);
                                  }
                                  _dragAccumulatorX = 0.0;
                                  _dragAccumulatorY = 0.0;
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: b.color.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white24,
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: b.color.withValues(
                                        alpha: isSelected ? 0.6 : 0.25,
                                      ),
                                      blurRadius: isSelected ? 12 : 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    b.isTarget
                                        ? Icons.vpn_key_rounded
                                        : Icons.open_with_rounded,
                                    color: b.isTarget
                                        ? Colors.black
                                        : Colors.white70,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 4-Directional D-Pad for the selected block
          if (_selectedBlock != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF141726),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _selectedBlock!.color.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedBlock!.isTarget ? 'Prime Core: ' : 'Conduit: ',
                    style: TextStyle(
                      color: _selectedBlock!.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: _canMoveSelected(-1, 0)
                        ? Colors.white
                        : Colors.white24,
                    onPressed: _canMoveSelected(-1, 0)
                        ? () => _moveSelected(-1, 0)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded),
                    color: _canMoveSelected(0, -1)
                        ? Colors.white
                        : Colors.white24,
                    onPressed: _canMoveSelected(0, -1)
                        ? () => _moveSelected(0, -1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward_rounded),
                    color: _canMoveSelected(0, 1)
                        ? Colors.white
                        : Colors.white24,
                    onPressed: _canMoveSelected(0, 1)
                        ? () => _moveSelected(0, 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    color: _canMoveSelected(1, 0)
                        ? Colors.white
                        : Colors.white24,
                    onPressed: _canMoveSelected(1, 0)
                        ? () => _moveSelected(1, 0)
                        : null,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent.withValues(alpha: 0.15),
              foregroundColor: Colors.orangeAccent,
            ),
            onPressed: _usePowerUpShiftCore,
            icon: const Icon(Icons.fast_forward_rounded, size: 18),
            label: const Text('Forward Warp (35 Pts)'),
          ),
        ],
      ),
    );
  }
}

class _GameScaffold extends StatelessWidget {
  final String title;
  final int stage;
  final int movesLeft;
  final bool isSolved;
  final bool isGameOver;
  final VoidCallback onRestart;
  final Widget body;

  const _GameScaffold({
    required this.title,
    required this.stage,
    required this.movesLeft,
    required this.isSolved,
    required this.isGameOver,
    required this.onRestart,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Restart Stage',
                onPressed: onRestart,
              ),
            ],
          ),
          body: SafeArea(
            child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatBadge(label: 'Stage', value: '$stage'),
                _StatBadge(
                  label: 'Global Pts',
                  value: '${globalPoints.points}',
                  isHighlight: true,
                ),
                _StatBadge(
                  label: 'Moves Left',
                  value: '$movesLeft',
                  color: movesLeft <= 3
                      ? Colors.redAccent
                      : globalPoints.activeTheme.primary,
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 10,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 460,
                  maxHeight: 540,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    body,
                    ParticleBurstOverlay(trigger: isSolved),
                    if (isGameOver) _buildGameOverOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        _buildSuccessBanner(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 960),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  body,
                  ParticleBurstOverlay(trigger: isSolved),
                  if (isGameOver) _buildGameOverOverlay(),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF111422),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TELEMETRY DASHBOARD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: globalPoints.activeTheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Divider(height: 24, color: Colors.white12),
                    _StatBadge(
                      label: 'Active Chamber / Stage',
                      value: '$stage',
                    ),
                    const SizedBox(height: 16),
                    _StatBadge(
                      label: 'Moves / Reserve Operations',
                      value: '$movesLeft',
                      color: movesLeft <= 3
                          ? Colors.redAccent
                          : globalPoints.activeTheme.primary,
                    ),
                    const SizedBox(height: 16),
                    _StatBadge(
                      label: 'Synced Global Wallet',
                      value: '${globalPoints.points} PTS',
                      isHighlight: true,
                    ),
                    const SizedBox(height: 24),
                    _buildSuccessBanner(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SIGNAL DEPLETED',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Out of moves for this stage.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: onRestart,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return AnimatedOpacity(
      opacity: isSolved ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          color: globalPoints.activeTheme.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: globalPoints.activeTheme.primary.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          '⚡ Stage Complete! Points Awarded',
          style: TextStyle(
            color: globalPoints.activeTheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final Color? color;

  const _StatBadge({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color:
                color ??
                (isHighlight ? globalPoints.activeTheme.primary : Colors.white),
          ),
        ),
      ],
    );
  }
}

class GlowingTilePainter extends CustomPainter {
  final NodeTile tile;
  GlowingTilePainter({required this.tile});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final isPowered = tile.isPowered;

    final bgPaint = Paint()
      ..color = isPowered ? const Color(0xFF0E2235) : const Color(0xFF161924)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isPowered
          ? globalPoints.activeTheme.primary.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    if (isPowered) {
      final glowPaint = Paint()
        ..color = globalPoints.activeTheme.primary.withValues(alpha: 0.7)
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
      _drawLines(canvas, size, center, glowPaint);
    }

    final corePaint = Paint()
      ..color = isPowered ? Colors.white : const Color(0xFF3B4058)
      ..strokeWidth = isPowered ? 4.5 : 5.0
      ..strokeCap = StrokeCap.round;
    _drawLines(canvas, size, center, corePaint);

    if (tile.isSource) {
      canvas.drawCircle(
        center,
        13,
        Paint()
          ..color = Colors.amberAccent.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0),
      );
      canvas.drawCircle(center, 9, Paint()..color = Colors.amberAccent);
      canvas.drawCircle(center, 4, Paint()..color = Colors.white);
    } else if (tile.isTarget) {
      final col = isPowered ? Colors.tealAccent : const Color(0xFFFF5252);
      canvas.drawCircle(
        center,
        13,
        Paint()
          ..color = col.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0),
      );
      canvas.drawCircle(center, 9, Paint()..color = col);
      canvas.drawCircle(center, 4, Paint()..color = Colors.white);
    } else {
      canvas.drawCircle(
        center,
        isPowered ? 5.5 : 4.0,
        isPowered
            ? (Paint()..color = globalPoints.activeTheme.primary)
            : corePaint,
      );
    }
  }

  void _drawLines(Canvas canvas, Size size, Offset center, Paint paint) {
    if ((tile.connections & 1) != 0) {
      canvas.drawLine(center, Offset(size.width / 2, 0), paint);
    }
    if ((tile.connections & 2) != 0) {
      canvas.drawLine(center, Offset(size.width, size.height / 2), paint);
    }
    if ((tile.connections & 4) != 0) {
      canvas.drawLine(center, Offset(size.width / 2, size.height), paint);
    }
    if ((tile.connections & 8) != 0) {
      canvas.drawLine(center, Offset(0, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GlowingTilePainter oldDelegate) => true;
}

class ArcadeEngineVerifier {
  static void runAllTests() {
    assert(
      _testBitmaskRotation(),
      'Synapse Node rotation bitmask test failed.',
    );
    assert(_testGridPowerPropagation(), 'Synapse DFS/BFS power test failed.');
    assert(_testBlockEscapeBoundaries(), 'Block Escape bounding test failed.');
    if (kDebugMode) {
      print(
        '✓ All Arcade Engine Logic & CS Verification Tests Passed Cleanly.',
      );
    }
  }

  static bool _testBitmaskRotation() {
    final tile = NodeTile(x: 0, y: 0, connections: 1);
    tile.rotate();
    return tile.currentConnections == 2;
  }

  static bool _testGridPowerPropagation() {
    final grid = [
      [
        NodeTile(x: 0, y: 0, connections: 2, isSource: true),
        NodeTile(x: 1, y: 0, connections: 8),
      ],
      [
        NodeTile(x: 0, y: 1, connections: 0),
        NodeTile(x: 1, y: 1, connections: 0),
      ],
    ];
    SynapseEngine.evaluate(grid, 2);
    return grid[0][1].isPowered == true;
  }

  static bool _testBlockEscapeBoundaries() {
    final block = EscapeBlock(
      x: 4,
      y: 2,
      length: 2,
      isHorizontal: true,
      color: Colors.red,
    );
    return (block.x + block.width) == 6;
  }
}
