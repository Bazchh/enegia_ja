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
}

class CellModel {
  Building b;
  bool powered;

  CellModel({this.b = Building.vazio, this.powered = false});

  factory CellModel.fromJson(Map<String, dynamic> json) => CellModel(
        b: Building.values.firstWhere(
          (e) => e.name == json['b'],
          orElse: () => Building.vazio,
        ),
        powered: json['powered'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'b': b.name,
        'powered': powered,
      };
}

class GameState {
  final int size;
  int turno = 1;
  double orcamento = 100; // créditos
  final metrics = Metrics();
  late List<List<CellModel>> grid;

  GameState({this.size = 10}) {
    grid = List.generate(size, () => List.generate(size, () => CellModel()));
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    final state = GameState(size: json['size'] ?? 10);
    state.turno = json['turno'] ?? 1;
    state.orcamento = (json['orcamento'] ?? 100).toDouble();

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

    return state;
  }

  void reset() {
    turno = 1;
    orcamento = 100;
    metrics
      ..acessoEnergia = 0
      ..limpa = 0
      ..tarifa = 1.0
      ..saude = 0.6
      ..educacao = 0.5
      ..desigualdade = 0.5
      ..clima = 0.6;
    for (var x = 0; x < size; x++) {
      for (var y = 0; y < size; y++) {
        grid[x][y] = CellModel();
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'size': size,
        'turno': turno,
        'orcamento': orcamento,
        'metrics': metrics.toJson(),
        'grid': [
          for (final row in grid) [for (final cell in row) cell.toJson()],
        ],
      };

  bool venceu() =>
      metrics.acessoEnergia >= 0.80 &&
      metrics.limpa >= 0.80 &&
      metrics.tarifa <= 1.0;

  bool acabou() => turno > 20 || venceu();
}