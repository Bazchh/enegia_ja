Plano Formal – Especificação Estilo Z
====================================

Esta especificação resume as invariantes centrais do jogo Energia Já usando notação inspirada em Z, cobrindo as fases 0–14 já implementadas (com pendências para 15–17). Ela espelha a estrutura em `lib/game/state/game_state.dart` e as operações definidas em `lib/game/energy_game.dart`.

Nota: notação ASCII com substituições (`->` para funções totais, `|` para separadores). `N` denota naturais, `B` booleanos.

1. Estruturas básicas
---------------------

```
PLAYER  ::= identificadores de jogadores (strings)
COORD   ::= pares (x,y) com 0 <= x,y < size
Building::= vazio | solar | eolica | eficiencia | saneamento
```

```
Metrics == [
  acessoEnergia : [0,1];
  limpa         : [0,1];
  tarifa        : [0,1.4];
  saude         : [0,1];
  educacao      : [0,1];
  desigualdade  : [0,1];
  clima         : [0,1]
]
```

```
Cell == [
  b      : Building;
  powered: B;
  owner  : PLAYER?
|
  (b = vazio) => (powered = false)
]
```

```
PlayerState == [
  orcamento : N;
  metrics   : Metrics
|
  orcamento >= 0
]
```

```
GameState == [
  size         : N1;
  turno        : N1;
  grid         : COORD -> Cell;
  metrics      : Metrics;
  playerStates : PLAYER -> PlayerState;
  bestClean    : [0,1];
  bestTurn     : N1
|
  size = 10;
  dom grid = { (x,y) | 0 <= x,y < size };
  forall (x,y) in dom grid @ (grid(x,y).owner != null => grid(x,y).b != vazio);
  forall p in ran(grid.owner) @ p in dom playerStates;
  bestTurn >= turno
]
```

2. Invariantes derivadas
------------------------

```
InvBudgets == forall p in dom playerStates @ playerStates(p).orcamento >= 0
InvMetrics == metrics in Metrics /
              forall p in dom playerStates @ playerStates(p).metrics in Metrics
InvBounds  == forall (x,y) in dom grid @ 0 <= x,y < size
```

3. Operações principais
-----------------------

### Inicialização
```
InitGame == [ GameState' |
  size' = 10 /
  turno' = 1 /
  grid'  = { (x,y) | 0 <= x,y < 10 } >-> Cell(b=vazio, powered=false, owner=null) /
  playerStates' = {} /
  metrics' = Metrics(0,0,1,0.6,0.5,0.5,0.6) /
  bestClean' = 0 /
  bestTurn' = 999
]
```

### Garantir jogador
```
EnsurePlayer == [ Delta GameState; pid?: PLAYER |
  pid? != null /
  playerStates' = playerStates <+ { pid? |-> PlayerState(orcamento=100, metrics=Metrics(0,0,1,0.6,0.5,0.5,0.6)) } /
  size'  = size /
  turno' = turno /
  grid'  = grid /
  metrics' = metrics /
  bestClean' = bestClean /
  bestTurn'  = bestTurn
]
```

### Colocação (`PlaceAt`)
```
CanControl(pid,x,y) ==
  let c == grid(x,y) @
    (c.owner = pid) \/
    (c.owner = null /\ NoTerritory(pid)) \/
    (c.owner = null /\ AdjacentOwned(pid,x,y))

NoTerritory(pid) == not (exists (i,j) @ grid(i,j).owner = pid)

AdjacentOwned(pid,x,y) ==
  exists (dx,dy) in {(1,0),(-1,0),(0,1),(0,-1)} @
    let nx == x+dx; ny == y+dy @
      (0 <= nx,ny < size) /\ grid(nx,ny).owner = pid

Cost(solar)=8.5; Cost(eolica)=10; Cost(eficiencia)=6.5; Cost(saneamento)=7; Cost(vazio)=0
```

```
PlaceAtOk == [ Delta GameState; pid?: PLAYER; x?,y?: N; b?: Building |
  (x?,y?) in dom grid /
  grid(x?,y?).b = vazio /
  CanControl(pid?,x?,y?) /
  playerStates(pid?).orcamento >= Cost(b?) /
  playerStates' = playerStates <+ { pid? |-> playerStates(pid?) with [orcamento := orcamento - Cost(b?)] } /
  grid' = grid <+ { (x?,y?) |-> grid(x?,y?) with [b := b?, powered := true, owner := pid?] } /
  turno' = turno /
  size' = size /
  metrics' = RecomputeMetrics(grid') /
  playerStates' metrics atualizados conforme grid' /
  bestClean', bestTurn' = CaptureProgress(metrics', turno', bestClean, bestTurn)
]
```

Falhas (`semOrcamento`, `invalido`, etc.) usam o esquema `Xi GameState` (estado inalterado).

### Remoção
```
RemoveAtOk == [ Delta GameState; pid?: PLAYER; x?,y?: N |
  (x?,y?) in dom grid /
  grid(x?,y?).b != vazio /
  grid(x?,y?).owner = pid? /
  refund == Cost(grid(x?,y?).b) / 2 /
  playerStates' = playerStates <+ { pid? |-> playerStates(pid?) with [orcamento := orcamento + refund] } /
  grid' = grid <+ { (x?,y?) |-> grid(x?,y?) with [b := vazio, powered := false, owner := null] } /
  metrics' = RecomputeMetrics(grid') /
  turno' = turno /
  size' = size /
  bestClean' = bestClean /
  bestTurn'  = bestTurn
]
```

### Fim de turno
```
GameFinished(metrics, turno) == (turno > 20) \/ (metrics.acessoEnergia >= 0.80 /\ metrics.limpa >= 0.80 /\ metrics.tarifa <= 1.0)
```

```
EndTurnOk == [ Delta GameState |
  not GameFinished(metrics, turno) /
  turno' = turno + 1 /
  size' = size /
  grid' = grid /
  playerStates' = { pid |-> ps with [orcamento := ps.orcamento + 4 + 0.5 * CountCells(pid, eficiencia)] | pid |-> ps in playerStates } /
  metrics' = RecomputeMetrics(grid) /
  bestClean', bestTurn' = CaptureProgress(metrics', turno', bestClean, bestTurn)
]
```

4. Pendências para Fases 15–17
------------------------------

- **Economia & Comércio:** estender `PlayerState` com campos `energiaGerada`, `energiaConsumida`, `recursos`, adicionando operação `Trade` com conservação (`sum saldo = 0`, estoques >= 0).
- **Clima & Eventos:** introduzir `WorldState` com `temperatura`, `poluicao`, `eventosAtivos`; modelar transições estocásticas e impactos em `metrics`.
- **Ranking & Vitórias:** definir `VictoryCondition ::= sustentabilidade | dominio | prosperidade`; operação `ComputeScore` mapeando jogador -> escore, ordenação total para ranking.

Este arquivo deve ser mantido sincronizado com `roadmap.md` e `plano_formal_resumo.md`, atualizando invariantes assim que novas fases forem implementadas ou especificadas.
