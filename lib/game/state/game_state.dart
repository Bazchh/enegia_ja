enum Building { vazio, solar, eolica, eficiencia, saneamento }

class Metrics {
  double acessoEnergia = 0; // 0..1
  double limpa = 0; // 0..1 (% da energia que é limpa)
  double tarifa = 1.0; // R$/kWh relativo (0.6..1.4)
  double saude = 0.6; // 0..1
  double educacao = 0.5; // 0..1
  double desigualdade = 0.5; // 0..1 (menor melhor)
  double clima = 0.6; // 0..1

  Metrics();

  Metrics.fromJson(Map<String, dynamic> json) {
    acessoEnergia = (json['acessoEnergia'] ?? 0).toDouble();
    limpa = (json['limpa'] ?? 0).toDouble();
    tarifa = (json['tarifa'] ?? 1.0).toDouble();
    saude = (json['saude'] ?? 0.6).toDouble();
    educacao = (json['educacao'] ?? 0.5).toDouble();
    desigualdade = (json['desigualdade'] ?? 0.5).toDouble();
    clima = (json['clima'] ?? 0.6).toDouble();
  }

  Map<String, dynamic> toJson() => {
        'acessoEnergia': acessoEnergia,
        'limpa': limpa,
        'tarifa': tarifa,
        'saude': saude,
        'educacao': educacao,
        'desigualdade': desigualdade,
        'clima': clima,
      };

  void reset() {
    acessoEnergia = 0;
    limpa = 0;
    tarifa = 1.0;
    saude = 0.6;
    educacao = 0.5;
    desigualdade = 0.5;
    clima = 0.6;
  }
}

class CellModel {
  Building b;
  bool powered;
  String? ownerId;

  CellModel({
    this.b = Building.vazio,
    this.powered = false,
    this.ownerId,
  });

  factory CellModel.fromJson(Map<String, dynamic> json) => CellModel(
        b: Building.values.firstWhere(
          (e) => e.name == json['b'],
          orElse: () => Building.vazio,
        ),
        powered: json['powered'] ?? false,
        ownerId: json['ownerId']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'b': b.name,
        'powered': powered,
        if (ownerId != null) 'ownerId': ownerId,
      };
}

class PlayerState {
  double orcamento;
  final Metrics metrics;

  PlayerState({
    this.orcamento = 100,
    Metrics? metrics,
  }) : metrics = metrics ?? Metrics();

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
        orcamento: (json['orcamento'] ?? 100).toDouble(),
        metrics: json['metrics'] is Map<String, dynamic>
            ? Metrics.fromJson(json['metrics'] as Map<String, dynamic>)
            : Metrics(),
      );

  Map<String, dynamic> toJson() => {
        'orcamento': orcamento,
        'metrics': metrics.toJson(),
      };

  void reset() {
    orcamento = 100;
    metrics.reset();
  }
}

class GameState {
  final int size;
  int turno = 1;
  final metrics = Metrics();
  late List<List<CellModel>> grid;
  final Map<String, PlayerState> playerStates = {};

  GameState({this.size = 10}) {
    grid = List.generate(size, (_) => List.generate(size, (_) => CellModel()));
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    final state = GameState(size: json['size'] ?? 10);
    state.turno = json['turno'] ?? 1;

    if (json['metrics'] is Map<String, dynamic>) {
      final parsed = Metrics.fromJson(json['metrics']);
      state.metrics
        ..acessoEnergia = parsed.acessoEnergia
        ..limpa = parsed.limpa
        ..tarifa = parsed.tarifa
        ..saude = parsed.saude
        ..educacao = parsed.educacao
        ..desigualdade = parsed.desigualdade
        ..clima = parsed.clima;
    }

    if (json['grid'] is List) {
      final rows = json['grid'] as List;
      final minRows = rows.length.clamp(0, state.size);
      for (var x = 0; x < minRows; x++) {
        final row = rows[x];
        if (row is List) {
          final minCols = row.length.clamp(0, state.size);
          for (var y = 0; y < minCols; y++) {
            final cellJson = row[y];
            if (cellJson is Map<String, dynamic>) {
              state.grid[x][y] = CellModel.fromJson(cellJson);
            }
          }
        }
      }
    }

    if (json['players'] is Map<String, dynamic>) {
      final playersJson = json['players'] as Map<String, dynamic>;
      state.playerStates
        ..clear()
        ..addAll(playersJson.map(
          (key, value) => MapEntry(
            key,
            value is Map<String, dynamic>
                ? PlayerState.fromJson(value)
                : PlayerState(),
          ),
        ));
    }

    return state;
  }

  void ensurePlayer(String playerId) {
    playerStates.putIfAbsent(playerId, PlayerState.new);
  }

  PlayerState stateFor(String playerId) {
    ensurePlayer(playerId);
    return playerStates[playerId]!;
  }

  Iterable<String> get registeredPlayers => playerStates.keys;

  void reset() {
    turno = 1;
    metrics.reset();
    for (var x = 0; x < size; x++) {
      for (var y = 0; y < size; y++) {
        grid[x][y] = CellModel();
      }
    }
    for (final player in playerStates.values) {
      player.reset();
    }
  }

  Map<String, dynamic> toJson() => {
        'size': size,
        'turno': turno,
        'metrics': metrics.toJson(),
        'grid': [
          for (final row in grid) [for (final cell in row) cell.toJson()],
        ],
        'players': {
          for (final entry in playerStates.entries) entry.key: entry.value.toJson(),
        },
      };

  bool venceu() =>
      metrics.acessoEnergia >= 0.80 &&
      metrics.limpa >= 0.80 &&
      metrics.tarifa <= 1.0;

  bool acabou() => turno > 20 || venceu();
}
