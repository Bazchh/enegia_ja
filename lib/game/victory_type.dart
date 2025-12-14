enum VictoryType {
  sustentavel, // Maior energia limpa + acesso
  economica, // Maior orçamento acumulado
  cientifica, // Melhor eficiência média
  territorial, // Maior área controlada
  coletiva, // Todos vencem se clima global bom
}

class VictoryCondition {
  final VictoryType type;
  final String name;
  final String description;
  final String icon;

  const VictoryCondition({
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
  });

  static const sustentavel = VictoryCondition(
    type: VictoryType.sustentavel,
    name: 'Vitória Sustentável',
    description: 'Maior energia limpa e acesso à energia',
    icon: '♻️',
  );

  static const economica = VictoryCondition(
    type: VictoryType.economica,
    name: 'Vitória Econômica',
    description: 'Maior orçamento acumulado',
    icon: '💰',
  );

  static const cientifica = VictoryCondition(
    type: VictoryType.cientifica,
    name: 'Vitória Científica',
    description: 'Melhor eficiência energética média',
    icon: '🔬',
  );

  static const territorial = VictoryCondition(
    type: VictoryType.territorial,
    name: 'Vitória Territorial',
    description: 'Maior área de território controlado',
    icon: '🗺️',
  );

  static const coletiva = VictoryCondition(
    type: VictoryType.coletiva,
    name: 'Vitória Coletiva',
    description: 'Todos vencem mantendo clima saudável',
    icon: '🌍',
  );

  static const all = [
    sustentavel,
    economica,
    cientifica,
    territorial,
    coletiva,
  ];
}

class PlayerScore {
  final String playerId;
  final String color;

  // Pontuações por categoria
  final double sustentabilidade; // limpa + acesso
  final double economia; // orçamento total
  final double ciencia; // eficiência média
  final int territorio; // células controladas

  // Vitórias conquistadas
  final Set<VictoryType> victories;

  PlayerScore({
    required this.playerId,
    required this.color,
    this.sustentabilidade = 0.0,
    this.economia = 0.0,
    this.ciencia = 0.0,
    this.territorio = 0,
    Set<VictoryType>? victories,
  }) : victories = victories ?? {};

  double get totalScore =>
      sustentabilidade * 100 +
      economia +
      ciencia * 50 +
      territorio.toDouble() * 10;

  PlayerScore copyWith({
    String? playerId,
    String? color,
    double? sustentabilidade,
    double? economia,
    double? ciencia,
    int? territorio,
    Set<VictoryType>? victories,
  }) =>
      PlayerScore(
        playerId: playerId ?? this.playerId,
        color: color ?? this.color,
        sustentabilidade: sustentabilidade ?? this.sustentabilidade,
        economia: economia ?? this.economia,
        ciencia: ciencia ?? this.ciencia,
        territorio: territorio ?? this.territorio,
        victories: victories ?? this.victories,
      );
}
