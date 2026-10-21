import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/board.dart';
import '../../engine/cell.dart';
import '../theme.dart';
import '../tokens.dart';
import 'game_controller.dart';

/// Board grid with forgiving taps: the whole board (plus [Tk.tapSlop] around
/// it) is one hit area and a tap goes to the nearest cell, so every cell
/// gets its full pitch (cell + gap) as target. Cells are 38dp + 2dp gap at
/// 9 columns (design) and scale up to fill the width on narrower levels,
/// which gives >= 44dp targets on a 360dp screen for <= 8 columns.
class BoardView extends StatelessWidget {
  const BoardView({super.key, required this.controller});

  final GameController controller;

  static const double maxPitch = 52;

  static double pitchFor(double width, int columns) =>
      math.min(maxPitch, (width - 2 * Tk.tapSlop) / columns).floorToDouble();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = controller;
      final board = c.state.board;
      final pitch = pitchFor(box.maxWidth, board.columns);
      final w = pitch * board.columns, h = pitch * board.rows;
      final ink = Theme.of(context).extension<GamePalette>()!;
      return Center(
        child: GestureDetector(
          key: const Key('board'),
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final x = d.localPosition.dx - Tk.tapSlop, y = d.localPosition.dy - Tk.tapSlop;
            final col = (x / pitch).floor().clamp(0, board.columns - 1);
            final row = (y / pitch).floor().clamp(0, board.rows > 0 ? board.rows - 1 : 0);
            if (board.rows > 0) c.tapCell(board.index(row, col));
          },
          child: Padding(
            padding: const EdgeInsets.all(Tk.tapSlop),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  for (var i = 0; i < board.length; i++)
                    Positioned(
                      left: board.colOf(i) * pitch,
                      top: board.rowOf(i) * pitch,
                      width: pitch,
                      height: pitch,
                      child: Padding(
                        padding: const EdgeInsets.all(Tk.cellGap / 2),
                        child: _AnimatedCell(
                          key: Key('cell-$i'),
                          cell: board[i],
                          look: _lookFor(c, i),
                          shake: c.shaking.contains(i) ? c.shakeTick : null,
                          clearing: c.clearing != null && (c.clearing!.$1 == i || c.clearing!.$2 == i),
                          blocked: c.blockedCell == i,
                          size: pitch - Tk.cellGap,
                        ),
                      ),
                    ),
                  if (c.clearing != null)
                    IgnorePointer(
                      child: CustomPaint(
                        key: const Key('pair-line'),
                        size: Size(w, h),
                        painter: _LinePainter(board, c.clearing!, pitch, ink.line),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  static CellLook _lookFor(GameController c, int i) {
    if (c.shaking.contains(i) && c.blockedCell != i) return CellLook.invalid;
    if (c.selected == i || (c.clearing != null && (c.clearing!.$1 == i || c.clearing!.$2 == i))) {
      return CellLook.selected;
    }
    if (c.hintPair != null && (c.hintPair!.$1 == i || c.hintPair!.$2 == i)) return CellLook.hint;
    return CellLook.normal;
  }
}

enum CellLook { normal, selected, hint, invalid }

class _LinePainter extends CustomPainter {
  _LinePainter(this.board, this.pair, this.pitch, this.color);
  final Board board;
  final (int, int) pair;
  final double pitch;
  final Color color;

  Offset _c(int i) => Offset((board.colOf(i) + .5) * pitch, (board.rowOf(i) + .5) * pitch);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_c(pair.$1), _c(pair.$2), p);
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.pair != pair || o.pitch != pitch || o.color != color;
}

class _AnimatedCell extends StatelessWidget {
  const _AnimatedCell({
    super.key,
    required this.cell,
    required this.look,
    required this.shake,
    required this.clearing,
    required this.blocked,
    required this.size,
  });

  final Cell cell;
  final CellLook look;
  final int? shake;
  final bool clearing;
  final bool blocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget w = CellTile(cell: cell, look: look, blocked: blocked, size: size);
    if (clearing) {
      w = TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: Tk.clear,
        curve: Curves.easeIn,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.scale(scale: .6 + .4 * v, child: child),
        ),
        child: w,
      );
    }
    if (shake != null) {
      w = TweenAnimationBuilder<double>(
        key: ValueKey('shake-$shake'),
        tween: Tween(begin: 0, end: 1),
        duration: Tk.shake,
        builder: (_, v, child) =>
            Transform.translate(offset: Offset(math.sin(v * math.pi * 6) * Tk.shakeAmp * (1 - v), 0), child: child),
        child: w,
      );
    }
    return w;
  }
}

/// One cell with all its layers (number, star, grass, stone, ice hp2/hp1,
/// slime) and the selection/hint/invalid looks from the visual set.
class CellTile extends StatelessWidget {
  const CellTile({
    super.key,
    required this.cell,
    this.look = CellLook.normal,
    this.blocked = false,
    this.size = Tk.cell,
  });

  final Cell cell;
  final CellLook look;
  final bool blocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.extension<GamePalette>()!;
    final scheme = theme.colorScheme;
    final o = cell.obstacle;
    final ice = o?.kind == ObstacleKind.ice && o!.hp > 0 ? o.hp : 0;

    var fill = ink.cell;
    var border = ink.cellBorder;
    var borderWidth = 1.5;
    var digit = scheme.onSurface;
    Widget? deco;

    if (cell.isEmpty) {
      fill = ink.cleared;
      border = ink.cleared;
    } else if (o?.kind == ObstacleKind.stone) {
      fill = ink.stone;
      border = ink.stone;
      deco = _Inset(color: ink.cell.withValues(alpha: .35), dashed: true);
    } else if (o?.kind == ObstacleKind.slime) {
      fill = ink.slime;
      border = ink.slime;
      deco = CustomPaint(painter: _WavePainter(ink.cell.withValues(alpha: .45)));
    } else {
      if (cell.grass) {
        fill = ink.grass;
        border = ink.grass;
        deco = CustomPaint(painter: _GrassPainter(ink.hintBorder));
      }
      if (cell.item == CellItem.star) {
        border = ink.star;
        borderWidth = 2;
      }
      if (ice > 0) {
        fill = ink.ice;
        border = ink.cellBorder;
        digit = ink.textMuted;
        deco = Stack(
          fit: StackFit.expand,
          children: [
            _Inset(color: ink.selected, dashed: true),
            if (ice == 1) CustomPaint(painter: _CrackPainter(scheme.onSurface)),
          ],
        );
      }
    }

    switch (look) {
      case CellLook.selected:
        fill = ink.selected;
        border = ink.selected;
        digit = scheme.onPrimary;
      case CellLook.hint:
        fill = ink.hint;
        border = ink.hintBorder;
        borderWidth = 2;
      case CellLook.invalid:
        border = scheme.error;
        borderWidth = 2;
        digit = scheme.error;
      case CellLook.normal:
        break;
    }

    final scale = size / Tk.cell;
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Tk.rCell),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (deco != null) ClipRRect(borderRadius: BorderRadius.circular(Tk.rCell - 2), child: deco),
          if (cell.value != null)
            Center(
              child: Text(
                '${cell.value}',
                style: TextStyle(fontSize: Tk.cellDigitSize * scale, fontWeight: FontWeight.w700, color: digit),
              ),
            ),
          if (cell.item == CellItem.star && cell.value != null)
            Positioned(
              right: 2,
              top: 0,
              child: Text(
                '★',
                style: TextStyle(fontSize: 11 * scale, color: ink.star),
              ),
            ),
          if (blocked)
            Center(
              child: Icon(Icons.close, key: const Key('blocked-x'), color: scheme.error, size: size * .8),
            ),
        ],
      ),
    );
  }
}

class _Inset extends StatelessWidget {
  const _Inset({required this.color, this.dashed = false});
  final Color color;
  final bool dashed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Tk.xs),
    child: CustomPaint(painter: _DashPainter(color, dashed)),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.dashed);
  final Color color;
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4));
    if (!dashed) {
      canvas.drawRRect(r, p);
      return;
    }
    final path = Path()..addRRect(r);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 6) {
        canvas.drawPath(m.extractPath(d, d + 3), p);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.color != color;
}

class _CrackPainter extends CustomPainter {
  _CrackPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(
      Path()
        ..moveTo(s.width * .2, s.height * .15)
        ..lineTo(s.width * .45, s.height * .45)
        ..lineTo(s.width * .35, s.height * .6)
        ..lineTo(s.width * .7, s.height * .9),
      p,
    );
    canvas.drawLine(Offset(s.width * .8, s.height * .15), Offset(s.width * .62, s.height * .38), p);
  }

  @override
  bool shouldRepaint(_CrackPainter o) => o.color != color;
}

class _GrassPainter extends CustomPainter {
  _GrassPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    const n = 5;
    final w = s.width / n;
    for (var k = 0; k < n; k++) {
      canvas.drawPath(
        Path()
          ..moveTo(k * w + w * .15, s.height)
          ..lineTo(k * w + w * .5, s.height * .78)
          ..lineTo(k * w + w * .85, s.height)
          ..close(),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_GrassPainter o) => o.color != color;
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()..moveTo(0, s.height * .55);
    path.cubicTo(s.width * .3, s.height * .25, s.width * .5, s.height * .8, s.width, s.height * .4);
    path
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.color != color;
}
