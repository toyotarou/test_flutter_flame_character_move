import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const GameApp());

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    final game = SideScrollerDemo();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          children: [
            GameWidget(game: game),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ControlButton(icon: Icons.arrow_back, onTap: () => game.toggleLeft()),
                    _ControlButton(icon: Icons.arrow_upward, onTap: () => game.player.jump()),
                    _ControlButton(icon: Icons.stop, onTap: () => game.stopMove()),
                    _ControlButton(icon: Icons.arrow_forward, onTap: () => game.toggleRight()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

// ───────────────────────── ゲーム本体 ─────────────────────────
class SideScrollerDemo extends FlameGame with HasKeyboardHandlerComponents {
  late final Player player;

  double get groundY => size.y - 48 - 64;

  bool _leftActive = false;
  bool _rightActive = false;

  void toggleLeft() {
    _leftActive = true;
    _rightActive = false;
    _updateHorizontalInput();
  }

  void toggleRight() {
    _rightActive = true;
    _leftActive = false;
    _updateHorizontalInput();
  }

  void stopMove() {
    _leftActive = false;
    _rightActive = false;
    _updateHorizontalInput();
  }

  void _updateHorizontalInput() {
    player.horizontalInput =
        _leftActive
            ? -1
            : _rightActive
            ? 1
            : 0;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 背景（全体） ← 最初に追加
    add(RectangleComponent(size: size, paint: Paint()..color = const Color(0xFFEFEFEF)));

    // キャラの移動可能範囲帯 ← あとから追加することで上に重ねる
    const margin = 24.0;
    final band = RectangleComponent(
      position: Vector2(margin, 0),
      size: Vector2(size.x - margin * 2, size.y),
      // ignore: deprecated_member_use
      paint: Paint()..color = Colors.lightBlueAccent.withOpacity(0.1),
    );
    add(band);

    // プレイヤー追加
    player = Player(groundY: groundY);
    await add(player);
  }

  @override
  // ignore: must_call_super
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    player.horizontalInput =
        keysPressed.contains(LogicalKeyboardKey.arrowLeft) || keysPressed.contains(LogicalKeyboardKey.keyA)
            ? -1
            : keysPressed.contains(LogicalKeyboardKey.arrowRight) || keysPressed.contains(LogicalKeyboardKey.keyD)
            ? 1
            : 0;

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp)) {
      player.jump();
    }
    return KeyEventResult.handled;
  }
}

// ───────────────────────── プレイヤー ─────────────────────────
enum PState { idle, run }

// ignore: deprecated_member_use
class Player extends SpriteAnimationGroupComponent<PState> with HasGameRef<SideScrollerDemo> {
  static const double runSpeed = 40;
  static const double jumpVel = -450;
  static const double gravity = 900;

  static const int cols = 2;
  static const int rows = 2;
  static const double scaleFactor = 0.1;

  final double groundY;
  int horizontalInput = 1; // 初期状態：右移動
  bool facingLeft = false;
  Vector2 vel = Vector2.zero();
  late final Vector2 frameSize;

  Player({required this.groundY}) : super(anchor: Anchor.center, current: PState.idle);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final img = await game.images.load('player_sheet.png');
    final frameW = img.width / cols;
    final frameH = img.height / rows;
    frameSize = Vector2(frameW.toDouble(), frameH.toDouble());

    size = frameSize * scaleFactor;
    scale = Vector2.all(1.0);

    final runFrames = <SpriteAnimationFrame>[];
    for (int i = 0; i < 3; i++) {
      final x = (i % cols) * frameW;
      final y = (i ~/ cols) * frameH;
      final sprite = Sprite(img, srcPosition: Vector2(x, y), srcSize: frameSize);
      runFrames.add(SpriteAnimationFrame(sprite, 0.4));
    }

    final runAnim = SpriteAnimation(runFrames);
    final idleAnim = SpriteAnimation.spriteList([
      Sprite(img, srcPosition: Vector2.zero(), srcSize: frameSize),
    ], stepTime: 1);

    animations = {PState.idle: idleAnim, PState.run: runAnim};

    position = Vector2(120, groundY - size.y / 2);
  }

  void jump() {
    if (isOnGround) vel.y = jumpVel;
  }

  bool get isOnGround => position.y >= groundY - size.y / 2;

  @override
  void update(double dt) {
    super.update(dt);

    final leftLimit = size.x / 2;
    final rightLimit = gameRef.size.x - size.x / 2;
    final leftTurnAround = leftLimit + 24;
    final rightTurnAround = rightLimit - 24;

    if (position.x <= leftTurnAround && horizontalInput < 0) {
      horizontalInput = 1;
    } else if (position.x >= rightTurnAround && horizontalInput > 0) {
      horizontalInput = -1;
    }

    vel
      ..x = horizontalInput * runSpeed
      ..y += gravity * dt;
    position += vel * dt;

    if (isOnGround) {
      position.y = groundY - size.y / 2;
      vel.y = 0;
    }

    if (vel.x < 0 && !facingLeft) {
      flipHorizontallyAroundCenter();
      facingLeft = true;
    } else if (vel.x > 0 && facingLeft) {
      flipHorizontallyAroundCenter();
      facingLeft = false;
    }

    position.x = position.x.clamp(leftLimit, rightLimit);
    current = vel.x == 0 ? PState.idle : PState.run;
  }
}
