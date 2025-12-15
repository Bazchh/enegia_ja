import '../economy.dart';
import '../world_events.dart';

enum Building { vazio, solar, eolica, eficiencia, saneamento }

enum ResourceType {
  none,
  energyBonus,    // +20% produção de energia
  treasury,       // +5 orçamento por turno
  cleanSource,    // +15% sustentabilidade
  research,       // +10% educação/ciência
  fertileLand,    // -20% custo de construção
}

enum VisibilityState {
  unexplored,  // Nunca visto (escuro total)
  explored,    // Já visto mas não visível atualmente (semi-escuro)
  visible,     // Visível atualmente (normal)
}

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
  Map<String, double> influence; // Influência de cada jogador nesta célula
  bool justConquered; // Marca células recém-conquistadas para animação
  ResourceType resource; // Recurso estratégico nesta célula

  CellModel({
    this.b = Building.vazio,
    this.powered = false,
    this.ownerId,
    Map<String, double>? influence,
    this.justConquered = false,
    this.resource = ResourceType.none,
  }) : influence = influence ?? {};

  factory CellModel.fromJson(Map<String, dynamic> json) => CellModel(
        b: Building.values.firstWhere(
          (e) => e.name == json['b'],
          orElse: () => Building.vazio,
        ),
        powered: json['powered'] ?? false,
        ownerId: json['ownerId']?.toString(),
        influence: json['influence'] is Map
            ? Map<String, double>.from(
                (json['influence'] as Map).map(
                  (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
                ),
              )
            : {},
        resource: json['resource'] != null
            ? ResourceType.values.firstWhere(
                (e) => e.name == json['resource'],
                orElse: () => ResourceType.none,
              )
            : ResourceType.none,
      );

  Map<String, dynamic> toJson() => {
        'b': b.name,
        'powered': powered,
        if (ownerId != null) 'ownerId': ownerId,
        if (influence.isNotEmpty) 'influence': influence,
        if (resource != ResourceType.none) 'resource': resource.name,
      };
}

class PlayerState {
  double orcamento;
  final Metrics metrics;
  final PlayerEconomy economy;
  double influenciaEnergia; // Solar + Eólica
  double influenciaSocial; // Eficiência + Saneamento

  PlayerState({
    this.orcamento = 20, // Reduzido para forçar escolhas estratégicas iniciais
    Metrics? metrics,
    PlayerEconomy? economy,
    this.influenciaEnergia = 0.0,
    this.influenciaSocial = 0.0,
  })  : metrics = metrics ?? Metrics(),
        economy = economy ?? PlayerEconomy();

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
        orcamento: (json['orcamento'] ?? 100).toDouble(),
        metrics: json['metrics'] is Map<String, dynamic>
            ? Metrics.fromJson(json['metrics'] as Map<String, dynamic>)
            : Metrics(),
        economy: json['economy'] is Map<String, dynamic>
            ? PlayerEconomy.fromJson(json['economy'] as Map<String, dynamic>)
            : PlayerEconomy(),
        influenciaEnergia: (json['influenciaEnergia'] ?? 0.0).toDouble(),
        influenciaSocial: (json['influenciaSocial'] ?? 0.0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'orcamento': orcamento,
        'metrics': metrics.toJson(),
        'economy': economy.toJson(),
        'influenciaEnergia': influenciaEnergia,
        'influenciaSocial': influenciaSocial,
      };

  void reset() {
    orcamento = 20; // Reduzido para forçar escolhas estratégicas iniciais
    metrics.reset();
    economy.reset();
    influenciaEnergia = 0.0;
    influenciaSocial = 0.0;
  }

  double get influenciaTotal => influenciaEnergia + influenciaSocial;
}

class GameState {
  final int size;
  int turno = 1;
  final metrics = Metrics();
  final worldState = WorldState();
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

    if (json['worldState'] is Map<String, dynamic>) {
      final parsed = WorldState.fromJson(json['worldState']);
      state.worldState
        ..temperaturaGlobal = parsed.temperaturaGlobal
        ..poluicaoAtmosferica = parsed.poluicaoAtmosferica
        ..activeEvents = parsed.activeEvents;
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
    worldState.reset();
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
        'worldState': worldState.toJson(),
        'grid': [
          for (final row in grid) [for (final cell in row) cell.toJson()],
        ],
        'players': {
          for (final entry in playerStates.entries) entry.key: entry.value.toJson(),
        },
      };

  bool venceu() =>
      metrics.acessoEnergia >= 0.60 && // Reduzido de 80% para 60%
      metrics.limpa >= 0.60 &&          // Reduzido de 80% para 60%
      metrics.tarifa <= 1.1;            // Aumentado de 1.0 para 1.1 (mais margem)

  bool acabou() => turno > 20 || venceu();

  // Calcular território de um jogador
  int getTerritorySize(String playerId) {
    var count = 0;
    for (var x = 0; x < size; x++) {
      for (var y = 0; y < size; y++) {
        if (grid[x][y].ownerId == playerId) {
          count++;
        }
      }
    }
    return count;
  }
}
