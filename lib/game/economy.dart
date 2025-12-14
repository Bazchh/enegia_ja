/// Sistema econômico de geração, consumo e comércio de energia
class EnergyEconomy {
  // Geração de energia por tipo de construção (kWh por turno)
  static const generationRates = {
    'solar': 12.0,
    'eolica': 15.0,
  };

  // Consumo de energia por célula de território (kWh por turno)
  static const baseConsumptionPerCell = 1.5; // Reduzido de 2.0 para 1.5

  // Eficiência reduz consumo
  static const efficiencyBonus = 0.18; // Aumentado de 15% para 18% por eficiência

  /// Calcula geração total de energia para um jogador
  static double calculateGeneration(
    int solarCount,
    int windCount, {
    double solarMultiplier = 1.0,
    double windMultiplier = 1.0,
  }) {
    return solarCount * generationRates['solar']! * solarMultiplier +
        windCount * generationRates['eolica']! * windMultiplier;
  }

  /// Calcula consumo total de energia para um jogador
  static double calculateConsumption(
    int territorySize,
    int efficiencyCount,
  ) {
    final baseConsumption = territorySize * baseConsumptionPerCell;
    final efficiencyReduction = efficiencyCount * efficiencyBonus;
    return baseConsumption * (1.0 - efficiencyReduction.clamp(0, 0.7));
  }

  /// Calcula balanço energético (geração - consumo)
  static double calculateBalance(
    double generation,
    double consumption,
  ) {
    return generation - consumption;
  }

  /// Calcula impacto no orçamento baseado no balanço energético
  static double calculateEconomicImpact(
    double balance,
    double tariff,
  ) {
    if (balance >= 0) {
      // Superávit: vende energia excedente
      return balance * tariff * 0.75; // Preço de venda aumentado de 60% para 75%
    } else {
      // Déficit: compra energia do mercado
      return balance * tariff; // Preço de compra é 100% da tarifa (negativo)
    }
  }

  /// Preço dinâmico de mercado baseado na oferta/demanda global
  static double calculateMarketPrice(
    double totalGeneration,
    double totalConsumption,
    double baseTariff,
  ) {
    final balance = totalGeneration - totalConsumption;
    final demandRatio = totalConsumption / (totalGeneration + 1);

    // Mercado ajusta preço baseado em oferta/demanda
    if (balance >= 0) {
      // Superávit global: preços caem
      return baseTariff * (0.7 + demandRatio * 0.3);
    } else {
      // Déficit global: preços sobem
      return baseTariff * (1.0 + (1.0 - demandRatio) * 0.5);
    }
  }
}

class PlayerEconomy {
  double generation = 0; // kWh gerados
  double consumption = 0; // kWh consumidos
  double balance = 0; // Balanço (geração - consumo)
  double economicImpact = 0; // Impacto no orçamento (+/-créditos)

  PlayerEconomy();

  factory PlayerEconomy.fromJson(Map<String, dynamic> json) {
    return PlayerEconomy()
      ..generation = (json['generation'] ?? 0).toDouble()
      ..consumption = (json['consumption'] ?? 0).toDouble()
      ..balance = (json['balance'] ?? 0).toDouble()
      ..economicImpact = (json['economicImpact'] ?? 0).toDouble();
  }

  Map<String, dynamic> toJson() => {
        'generation': generation,
        'consumption': consumption,
        'balance': balance,
        'economicImpact': economicImpact,
      };

  void reset() {
    generation = 0;
    consumption = 0;
    balance = 0;
    economicImpact = 0;
  }

  void update({
    required double generation,
    required double consumption,
    required double tariff,
  }) {
    this.generation = generation;
    this.consumption = consumption;
    balance = EnergyEconomy.calculateBalance(generation, consumption);
    economicImpact = EnergyEconomy.calculateEconomicImpact(balance, tariff);
  }
}
