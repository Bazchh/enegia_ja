/// Sistema de eventos globais que afetam todos os jogadores
enum EventType {
  tempestadeSolar, // Bônus de energia solar
  ventosFavoraveis, // Bônus de energia eólica
  criseTarifaria, // Aumento temporário nas tarifas
  ondaDeCalor, // Penalidade no clima global
  surtoSaude, // Melhoria temporária na saúde
  investimentoPublico, // Bônus de orçamento
}

class WorldEvent {
  final EventType type;
  final String name;
  final String description;
  final String icon;
  final int duration; // Turnos de duração

  const WorldEvent({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    this.duration = 2,
  });

  static const tempestadeSolar = WorldEvent(
    type: EventType.tempestadeSolar,
    name: 'Tempestade Solar',
    description: 'Painéis solares geram 50% mais energia',
    icon: '☀️',
    duration: 3,
  );

  static const ventosFavoraveis = WorldEvent(
    type: EventType.ventosFavoraveis,
    name: 'Ventos Favoráveis',
    description: 'Turbinas eólicas são 40% mais eficientes',
    icon: '💨',
    duration: 2,
  );

  static const criseTarifaria = WorldEvent(
    type: EventType.criseTarifaria,
    name: 'Crise Tarifária',
    description: 'Todas as tarifas aumentam em 20%',
    icon: '📈',
    duration: 2,
  );

  static const ondaDeCalor = WorldEvent(
    type: EventType.ondaDeCalor,
    name: 'Onda de Calor',
    description: 'Clima global sofre -15% de penalidade',
    icon: '🌡️',
    duration: 3,
  );

  static const surtoSaude = WorldEvent(
    type: EventType.surtoSaude,
    name: 'Campanha de Saúde',
    description: 'Indicadores de saúde melhoram +10%',
    icon: '🏥',
    duration: 2,
  );

  static const investimentoPublico = WorldEvent(
    type: EventType.investimentoPublico,
    name: 'Investimento Público',
    description: 'Todos os jogadores recebem +15 créditos',
    icon: '💰',
    duration: 1,
  );

  static const all = [
    tempestadeSolar,
    ventosFavoraveis,
    criseTarifaria,
    ondaDeCalor,
    surtoSaude,
    investimentoPublico,
  ];
}

class ActiveEvent {
  final WorldEvent event;
  int turnsRemaining;

  ActiveEvent({
    required this.event,
    required this.turnsRemaining,
  });

  bool get isExpired => turnsRemaining <= 0;

  void tick() {
    turnsRemaining--;
  }

  factory ActiveEvent.fromJson(Map<String, dynamic> json) {
    final eventType = EventType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => EventType.tempestadeSolar,
    );
    final event = WorldEvent.all.firstWhere(
      (e) => e.type == eventType,
      orElse: () => WorldEvent.tempestadeSolar,
    );

    return ActiveEvent(
      event: event,
      turnsRemaining: json['turnsRemaining'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': event.type.name,
        'turnsRemaining': turnsRemaining,
      };
}

class WorldState {
  double temperaturaGlobal = 1.0; // 0.5 = muito fria, 1.5 = muito quente
  double poluicaoAtmosferica = 0.5; // 0..1
  List<ActiveEvent> activeEvents = [];

  WorldState();

  factory WorldState.fromJson(Map<String, dynamic> json) {
    final state = WorldState();
    state.temperaturaGlobal = (json['temperaturaGlobal'] ?? 1.0).toDouble();
    state.poluicaoAtmosferica = (json['poluicaoAtmosferica'] ?? 0.5).toDouble();

    if (json['activeEvents'] is List) {
      state.activeEvents = (json['activeEvents'] as List)
          .map((e) => ActiveEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return state;
  }

  Map<String, dynamic> toJson() => {
        'temperaturaGlobal': temperaturaGlobal,
        'poluicaoAtmosferica': poluicaoAtmosferica,
        'activeEvents': activeEvents.map((e) => e.toJson()).toList(),
      };

  void reset() {
    temperaturaGlobal = 1.0;
    poluicaoAtmosferica = 0.5;
    activeEvents.clear();
  }

  bool hasActiveEvent(EventType type) {
    return activeEvents.any((e) => e.event.type == type);
  }

  void tickEvents() {
    for (final event in activeEvents) {
      event.tick();
    }
    activeEvents.removeWhere((e) => e.isExpired);
  }

  void addEvent(WorldEvent event) {
    // Remover evento do mesmo tipo se já existe
    activeEvents.removeWhere((e) => e.event.type == event.type);

    // Adicionar novo evento
    activeEvents.add(ActiveEvent(
      event: event,
      turnsRemaining: event.duration,
    ));
  }
}
