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

class Block extends RectangleComponent {
  Block(Vector2 pos, double width)
    : super(position: pos, size: Vector2(width, 20), paint: Paint()..color = Colors.brown.shade300);
}

class SideScrollerDemo extends FlameGame with HasKeyboardHandlerComponents {
  late final Player player;

  double get groundY => size.y - 48 - 64;
  final List<Block> blockList = [];

  void toggleLeft() => player.horizontalInput = -1;

  void toggleRight() => player.horizontalInput = 1;

  void stopMove() => player.horizontalInput = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(RectangleComponent(size: size, paint: Paint()..color = const Color(0xFFEFEFEF)));

    add(
      RectangleComponent(
        position: Vector2(24, 0),
        size: Vector2(size.x - 48, size.y),
        // ignore: deprecated_member_use
        paint: Paint()..color = Colors.lightBlueAccent.withOpacity(0.1),
      ),
    );

    final yOffsets = [
      groundY - 80,
      groundY - 140,
      groundY - 200,
      groundY - 260,
      groundY - 320,
      groundY - 380,
      groundY - 440,
      groundY - 500,
    ];

    const int divisions = 10;
    final double blockWidth = size.x / divisions;

    final List<List<int>> pattern = [
      [1, 1, 0, 0, 1, 1, 1, 0, 0, 0],
      [1, 1, 0, 0, 1, 1, 1, 0, 0, 0],
      [1, 1, 0, 0, 1, 1, 1, 0, 0, 0],
      [1, 1, 0, 0, 1, 1, 1, 0, 0, 0],
      [1, 1, 0, 0, 1, 1, 1, 0, 0, 0],
      [1, 1, 0, 0, 1, 1, 1, 0, 0, 0],
      [1, 1, 0, 0, 1, 1, 1, 0, 0, 0],
      [1, 1, 0, 0, 1, 1, 1, 0, 0, 0],
    ];

    for (int row = 0; row < yOffsets.length; row++) {
      final y = yOffsets[row];
      for (int col = 0; col < divisions; col++) {
        if (pattern[row][col] == 1) {
          final x = col * blockWidth;
          final block = Block(Vector2(x, y), blockWidth);
          blockList.add(block);
          await add(block);
        }
      }
    }

    player = Player(groundY: groundY, blockList: blockList);
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
  final List<Block> blockList;
  int horizontalInput = 1;
  bool facingLeft = false;
  Vector2 vel = Vector2.zero();
  late final Vector2 frameSize;

  Player({required this.groundY, required this.blockList}) : super(anchor: Anchor.center, current: PState.idle);

  void jump() {
    final bottom = position.y + size.y / 2;
    if (bottom >= groundY - 0.1) {
      vel.y = jumpVel;
      return;
    }
    for (final block in blockList) {
      final bTop = block.position.y;
      final bLeft = block.position.x;
      final bRight = block.position.x + block.size.x;
      if (bottom >= bTop - 1 && bottom <= bTop + 6 && position.x >= bLeft && position.x <= bRight) {
        vel.y = jumpVel;
        return;
      }
    }
  }

  @override
  Future<void> onLoad() async {
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
    position = Vector2(60, groundY - size.y / 2);
  }

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

    double? closestBlockTop;

    for (final block in blockList) {
      final bTop = block.position.y;
      final bLeft = block.position.x;
      final bRight = block.position.x + block.size.x;
      final bottom = position.y + size.y / 2;

      if (bottom >= bTop - 1 && bottom <= bTop + 6 && position.x >= bLeft && position.x <= bRight) {
        if (closestBlockTop == null || bTop < closestBlockTop) {
          closestBlockTop = bTop;
        }
      }
    }

    if (closestBlockTop != null) {
      vel.y = 0;
      position.y = closestBlockTop - size.y / 2;
    } else if (position.y + size.y / 2 >= groundY) {
      vel.y = 0;
      position.y = groundY - size.y / 2;
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
