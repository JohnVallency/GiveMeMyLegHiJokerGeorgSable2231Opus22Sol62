import 'dart:math';

class Move {
  final int from, to, die;
  const Move(this.from, this.to, this.die);
}

/// White moves 23 → 0; black moves 0 → 23. Bar = -1, off = 24.
class Position {
  final List<int> points;
  final List<int> bar, off;
  Position(this.points, this.bar, this.off);
  factory Position.initial() {
    final p = List.filled(24, 0);
    p[23] = 2;
    p[12] = 5;
    p[7] = 3;
    p[5] = 5;
    p[0] = -2;
    p[11] = -5;
    p[16] = -3;
    p[18] = -5;
    return Position(p, [0, 0], [0, 0]);
  }
  Position copy() => Position([...points], [...bar], [...off]);
  int index(int player) => player == 1 ? 0 : 1;
  int pip(int player) {
    var n = bar[index(player)] * 25;
    for (var i = 0; i < 24; i++) {
      if (points[i] * player > 0) {
        n += points[i].abs() * (player == 1 ? i + 1 : 24 - i);
      }
    }
    return n;
  }

  List<Move> moves(int player, int die) {
    final result = <Move>[];
    final onBar = bar[index(player)] > 0;
    final sources = onBar
        ? [-1]
        : List.generate(24, (i) => i).where((i) => points[i] * player > 0);
    final home =
        !onBar &&
        !List.generate(
          24,
          (i) => i,
        ).any((i) => points[i] * player > 0 && (player == 1 ? i > 5 : i < 18));
    for (final from in sources) {
      final to = from == -1
          ? (player == 1 ? 24 - die : die - 1)
          : from - player * die;
      if (to >= 0 && to < 24) {
        if (points[to] * player >= -1) result.add(Move(from, to, die));
      } else if (home) {
        final distance = player == 1 ? from + 1 : 24 - from;
        final farther = List.generate(24, (i) => i).any(
          (i) => points[i] * player > 0 && (player == 1 ? i > from : i < from),
        );
        if (die == distance || !farther) result.add(Move(from, 24, die));
      }
    }
    return result;
  }

  Position play(int player, Move m) {
    final p = copy();
    if (m.from == -1) {
      p.bar[index(player)]--;
    } else {
      p.points[m.from] -= player;
    }
    if (m.to == 24) {
      p.off[index(player)]++;
    } else {
      if (p.points[m.to] == -player) {
        p.points[m.to] = 0;
        p.bar[index(-player)]++;
      }
      p.points[m.to] += player;
    }
    return p;
  }

  List<List<Move>> sequences(int player, List<int> dice) {
    if (dice.isEmpty || off[index(player)] == 15) return [[]];
    final paths = <List<Move>>[];
    for (final die in dice.toSet()) {
      final rest = [...dice]..remove(die);
      for (final move in moves(player, die)) {
        for (final tail in play(player, move).sequences(player, rest)) {
          paths.add([move, ...tail]);
        }
      }
    }
    if (paths.isEmpty) return [[]];
    final longest = paths.map((p) => p.length).reduce(max);
    var best = paths.where((p) => p.length == longest).toList();
    if (longest == 1 && dice.toSet().length > 1) {
      final high = best.map((p) => p.first.die).reduce(max);
      best = best.where((p) => p.first.die == high).toList();
    }
    return best;
  }
}

class LocalBot {
  final Random random;
  LocalBot(this.random);
  List<Move> choose(Position position, int player, List<int> dice, int level) {
    final paths = position.sequences(player, dice);
    if (level == 0) return paths[random.nextInt(paths.length)];
    double evaluate(List<Move> path) {
      var p = position;
      for (final m in path) {
        p = p.play(player, m);
      }
      var score =
          p.off[p.index(player)] * 140.0 -
          p.pip(player) +
          p.bar[p.index(-player)] * 22;
      for (var i = 0; i < 24; i++) {
        final count = p.points[i] * player;
        if (count >= 2) {
          score += 5 + (player == 1 ? (i < 6 ? 5 : 0) : (i > 17 ? 5 : 0));
        }
        if (count == 1) {
          score -= 4;
          if (level == 2) {
            for (var d = 1; d <= 12; d++) {
              final attacker = i - player * d;
              if (attacker >= 0 &&
                  attacker < 24 &&
                  p.points[attacker] * player < 0) {
                score -= d <= 6 ? 4 : 1;
              }
            }
          }
        }
      }
      return score + random.nextDouble() * (level == 1 ? 8 : 0.2);
    }

    var best = paths.first;
    var value = double.negativeInfinity;
    for (final path in paths) {
      final score = evaluate(path);
      if (score > value) {
        best = path;
        value = score;
      }
    }
    return best;
  }
}
