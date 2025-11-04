Plano Formal - Resumo Integrado
===============================

Este arquivo resume o que ja esta documentado em `_artefatos/plano_formal/plano_formal.pdf`, indica o status das fases descritas em `roadmap.md` e liga cada marco aos pontos do codigo que sustentam as invariantes do projeto Energia Ja.

Contexto
--------
- Roadmap de implementacao: `roadmap.md` (fases 0 a 17).
- Codigo-fonte principal: `lib/game/state/game_state.dart`, `lib/game/energy_game.dart`, `lib/ui/hud.dart`, `lib/game/components/cell.dart`, `lib/multiplayer/*`.
- Artefatos formais: `_artefatos/plano_formal/plano_formal.pdf` (especificacao geral) e este resumo textual.

Resumo por Fase
---------------
- **Fase 0 - Estado Basico (Concluida)**: define `GameState`, `Metrics` e regras de vitoria/derrota (`lib/game/state/game_state.dart`). Invariantes base de grid e condicao de vitoria.
- **Fase 1 - HUD Inicial (Concluida)**: apresenta metricas e botoes na HUD (`lib/ui/hud.dart`). Sem impacto direto em invariantes, mas mostra dados de `GameState`.
- **Fase 2 - Colocacao/Remocao (Concluida)**: `EnergyGame.placeAt` e `endTurn` tratam orcamento, custo e reembolso (`lib/game/energy_game.dart:178`). Fundamenta invariantes de saldo e turnos.
- **Fase 3 - Recomputo de Metricas (Concluida)**: `_recomputeMetrics` calcula metricas globais e por jogador (`lib/game/energy_game.dart:247`). Mantem limites [0,1].
- **Fase 4 - Toque no Grid (Concluida)**: integra celulas com logica de construcao (`lib/game/components/cell.dart`). Deve sempre delegar a `placeAt`.
- **Fase 5 - Botao de Proximo Turno (Concluida)**: HUD chama `endTurn` (`lib/ui/hud.dart`).
- **Fase 6 - Recordes Persistentes (Concluida)**: `_loadProgress`, `_saveProgress` e `_captureProgress` (`lib/game/energy_game.dart:405`). Requer consistencia de bestClean/bestTurn.
- **Fase 7 - Declaracao de Assets (Concluida)**: `pubspec.yaml`. Nenhuma implicacao de invariantes.
- **Fase 8 - Balanceamento (Pendente)**: ajustar pesos em `_recomputeMetrics` mantendo clamps. Depende de analise formal de funcoes de custo/beneficio.
- **Fase 9 - UX Refinada (Concluida)**: melhorias visuais; invariantes permanecem as mesmas.
- **Fase 10 - Salvar/Carregar Estado (Concluida)**: `GameState.toJson/fromJson` e `saveGame` (`lib/game/state/game_state.dart:184`, `lib/game/energy_game.dart:430`). Garante serializacao total.
- **Fase 11 - Multiplayer Autoritativo (Concluida)**: orquestracao de turnos e sincronizacao via servidor (`lib/multiplayer/game_socket.dart`, `lib/multiplayer/multiplayer_game.dart`). Invariantes de turno unico ativo e estado autoritativo.
- **Fase 12 - Testes Automatizados (Pendente)**: criar `test/` para exercitar invariantes (ver secao "Rastreabilidade").
- **Fase 13 - Territorios e Propriedade (Concluida)**: `CellModel.ownerId`, coloracao por dono, restricao de construcao (`lib/game/state/game_state.dart`, `lib/game/energy_game.dart:178`, `lib/game/components/cell.dart`, `lib/ui/hud.dart`).
- **Fase 14 - Expansao e Influencia (Parcial)**: contagem de territorio via `_MetricAccumulator` implementada, faltam regras de disputa/expansao explicita (`lib/game/energy_game.dart:247`).
- **Fase 15 - Economia e Comercio (Pendente)**: ainda sem modelagem de energia gerada/consumida ou balanco comercial. Plano formal precisa definir recursos e operacoes financeiras.
- **Fase 16 - Clima e Eventos (Pendente)**: inexistente camada `WorldState`, eventos ou metricas globais de poluicao/temperatura.
- **Fase 17 - Ranking e Vitorias (Pendente)**: faltam tipos de vitoria adicionais, ranking final e `ScoreboardScreen`.

Invariantes Globais
-------------------
- **Turno monotono**: `state.turno` inicia em 1 e apenas cresce enquanto o jogo nao acabou (`lib/game/state/game_state.dart:171`, `lib/game/energy_game.dart:232`).
- **Orcamento nao negativo**: construcao proibida sem saldo (`lib/game/energy_game.dart:216`); reembolso credita o dono correto (`lib/game/energy_game.dart:196`).
- **Grade consistente**: manipulacao de celulas respeita limites (`lib/game/energy_game.dart:182`, `lib/game/energy_game.dart:347`) e dimensao fixa (`lib/game/state/game_state.dart:158`).
- **Serializacao total**: `GameState.toJson/fromJson` preserva grade, jogadores e metricas (`lib/game/state/game_state.dart:184`, `lib/game/state/game_state.dart:126`); `saveGame`/`loadGame` restauram estado valido (`lib/game/energy_game.dart:436`).
- **Identidade de jogador**: `setLocalPlayer` e `ensurePlayer` mantem consistencia do mapa de jogadores (`lib/game/energy_game.dart:56`, `lib/game/state/game_state.dart:138`).
- **Persistencia deterministica**: estados antigos sem bloco `players` sao harmonizados com orcamento padrao (`lib/game/energy_game.dart:450`).

Territorio e Propriedade (Fases 13-14)
--------------------------------------
- **Controle por dono**: somente proprietario atual ou jogador sem territorio pode agir na celula (`lib/game/energy_game.dart:362`).
- **Expansao adjacente**: jogadores com territorio so expandem para celulas adjacentes (`lib/game/energy_game.dart:376`).
- **Remocao segura**: impedida remocao de construcao de outro jogador (`lib/game/energy_game.dart:188`).

Metricas, Economia e Clima (Fases 8, 15, 16)
-------------------------------------------
- `_recomputeMetrics` mantem valores em [0,1] e tarifa calculada por fontes limpas/sujas (`lib/game/energy_game.dart:247`).
- Bonus de fim de turno dependem das celulas de eficiencia (`lib/game/energy_game.dart:239`).
- Para fases 15-16, o plano formal deve incluir novas variaveis (energia gerada/consumida, estoque de recursos, clima/poluicao) antes da implementacao.

Multiplayer e Sincronizacao (Fase 11)
-------------------------------------
- Apenas o jogador do turno pode executar `placeAt`/`endTurn`; estado sincronizado via servidor autoritativo (`lib/multiplayer/*`).
- Serializacao de mensagens deve preservar as invariantes descritas em `GameState` (detalhar no PDF ao modelar o protocolo).

Rastreabilidade Recomendada
---------------------------
- No PDF principal, manter matriz requisito -> invariante -> teste -> trecho de codigo (`placeAt`, `endTurn`, `_recomputeMetrics`, `GameState.toJson`).
- Ao iniciar a Fase 12, criar `test/` com casos derivados das invariantes listadas aqui.
- Atualizar este resumo sempre que uma fase trocar de status ou quando novos requisitos formais surgirem.

Proximos Passos
---------------
- Concluir Fase 14 detalhando disputa de territorio e atualizar invariantes.
- Planejar Fases 15-17 definindo contratos formais (economia, clima, ranking) antes da implementacao.
- Implantar testes automatizados que cubram cenarios positivos e negativos para cada invariante.
