  enum Building { vazio, solar, eolica, eficiencia, saneamento }

  class Metrics {
    double acessoEnergia = 0;   // 0..1
    double limpa = 0;           // 0..1 (% da energia que é limpa)
    double tarifa = 1.0;        // R$/kWh relativo (0.6..1.4)
    double saude = 0.6;         // 0..1
    double educacao = 0.5;      // 0..1
    double desigualdade = 0.5;  // 0..1 (menor melhor)
    double clima = 0.6;         // 0..1
  }

  class CellModel {
    Building b = Building.vazio;
    bool powered = false;
  }

  class GameState {
    final int size;
    int turno = 1;
    double orcamento = 100; // créditos
    final metrics = Metrics();
    late List<List<CellModel>> grid;

    GameState({this.size = 10}) {
      grid = List.generate(size, (_) => List.generate(size, (_) => CellModel()));
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

    bool venceu() =>
        metrics.acessoEnergia >= 0.80 &&
        metrics.limpa >= 0.80 &&
        metrics.tarifa <= 1.0;

    bool acabou() => turno > 20 || venceu();
  }
