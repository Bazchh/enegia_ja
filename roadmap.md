# Energia Já - Roteiro de Implementação

Este roteiro lista os principais marcos do projeto Energia Já e os prompts esperados para reproduzi-los. Cada fase indica o status atual.

---

## Fase 0 – Estado Básico do Jogo (Concluída)
**Objetivo:** Garantir estado base com métricas, grade e regras de vitória/derrota.
**Arquivos:** `lib/game/state/game_state.dart`

**Prompt sugerido:**
> Verifique se `Metrics`, `CellModel` e `GameState` contêm todos os campos e regras necessários:
> - Metrics: `acessoEnergia`, `limpa`, `tarifa`, `saude`, `educacao`, `desigualdade`, `clima`.
> - `CellModel` com `Building.vazio` como padrão e flag `powered`.
> - `GameState` com `size`, `turno`, `orcamento`, `metrics` e grade 2D.
> - Métodos `reset()`, `venceu()`, `acabou()` aplicando vitória (80% acesso/limpa, tarifa <= 1.0) e fim de jogo (turno > 20 ou vitória).
>
> **Commit:** `feat(core): ensure baseline GameState with metrics, grid and win/lose rules`

---

## Fase 1 – HUD Inicial (Concluída)
**Objetivo:** Exibir métricas, botões de construção, alternância de remoção, snackbar e barra de resultado.
**Arquivos:** `lib/ui/hud.dart`

**Prompt sugerido:**
> Confirme que o HUD apresenta:
> - Barra superior com Turno, Orçamento, Acesso, Limpa, Tarifa, Saúde, Educação, Melhor Limpa, Melhor Turno.
> - Barra de construção (Solar, Eólica, Eficiência, Saneamento) e botão Remover.
> - Snackbar “Orçamento insuficiente” quando `PlaceResult.semOrcamento`.
> - Barra de resultado com botão Reiniciar quando o jogo termina.
>
> **Commit:** `feat(ui): initial HUD with metrics, build buttons, remove toggle and result bar`

---

## Fase 2 – Lógica de Construção/Remoção e Custos (Concluída)
**Objetivo:** Implementar regras de construção/remoção vinculadas ao orçamento e resultado da ação.
**Arquivos:** `lib/game/energy_game.dart`

**Prompt sugerido:**
> Implementar:
> - Enum `PlaceResult` (`ok`, `semOrcamento`, `invalido`, `removido`).
> - Campos: `state`, `selecionado`, `removeMode`, `lastPlaceResult`, `bestClean`, `bestTurn`.
> - Funções `costOf`, `restart`, `placeAt`, `endTurn` com dedução/reembolso de orçamento e atualização de `lastPlaceResult`.
> - Invocar `_recomputeMetrics()` após mutações.
>
> **Commit:** `feat(core): implement building placement, removal and budget logic`

---

## Fase 3 – Recalculo de Métricas (Concluída)
**Objetivo:** Recalcular métricas a cada ação.
**Arquivo:** `lib/game/energy_game.dart`

**Prompt sugerido:**
> Implementar `_recomputeMetrics()` para varrer a grade, contabilizar fontes limpas, eficiência e saneamento, atualizando as métricas com clamp em [0,1].
>
> **Commit:** `feat(core): add dynamic metric recomputation after player actions`

---

## Fase 4 – Integração do Toque no Grid (Concluída)
**Objetivo:** Disparar construção/remoção ao tocar nas células.
**Arquivo:** `lib/game/components/cell.dart`

**Prompt sugerido:**
> Garantir que `onTapDown` chame `gameRef.placeAt(cx, cy)` respeitando `removeMode`.
>
> **Commit:** `feat(input): connect grid cell taps to game placement logic`

---

## Fase 5 – Botão de Próximo Turno (Concluída)
**Objetivo:** Permitir avançar turno manualmente pela HUD.
**Arquivo:** `lib/ui/hud.dart`

**Prompt sugerido:**
> Adicionar um `FilledButton` em `_buildBar` que chama `widget.game.endTurn()` ao pressionar.
>
> **Commit:** `feat(ui): add manual end-turn button in HUD`

---

## Fase 6 – Persistência dos Melhores Resultados (Concluída)
**Objetivo:** Salvar/carregar `bestClean` e `bestTurn` via SharedPreferences.
**Arquivo:** `lib/game/energy_game.dart`

**Prompt sugerido:**
> Implementar `_loadProgress()`, `_saveProgress()` e `_captureProgress()` armazenando os recordes e carregando-os na inicialização.
>
> **Commit:** `feat(progress): persist bestClean and bestTurn using shared_preferences`

---

## Fase 7 – Declaração de Assets (Concluída)
**Objetivo:** Declarar os ícones no `pubspec.yaml`.

**Prompt sugerido:**
> Em `flutter:`, adicionar os quatro caminhos em `assets/images/icons/`.
>
> **Commit:** `chore(assets): declare icon assets for HUD buttons`

---

## Fase 8 – Balanceamento (Pendente)
**Objetivo:** Ajustar parâmetros de `_recomputeMetrics()` para melhor equilíbrio de jogo.
**Arquivo:** `lib/game/energy_game.dart`

**Prompt sugerido:**
> Iterar em custos e pesos de energia limpa, eficiência, saneamento, tarifa e desigualdade para atingir o ritmo desejado.
>
> **Commit:** `balance: adjust metric weights and building costs for improved gameplay`

---

## Fase 9 – UX Refinada (Concluída)
**Objetivo:** Melhorar feedback e acessibilidade na HUD.
**Arquivo:** `lib/ui/hud.dart`

**Prompt sugerido:**
> Adicionar estados desabilitados quando o orçamento for insuficiente, tooltips para cada construção, pequenas animações/destaques e texto de status (“Sua vez” / “Aguardando o outro jogador”) no multiplayer.
>
> **Commit:** `feat(ui): add button states, tooltips and minor UX polish`

---

## Fase 10 – Salvar/Carregar Estado Completo (Concluída)
**Objetivo:** Persistir todo o `GameState` (grade, métricas, turno, orçamento).
**Arquivos:** `lib/game/state/game_state.dart`, `lib/game/energy_game.dart`

**Prompt sugerido:**
> Serializar `GameState` em JSON, salvar via SharedPreferences e carregar na inicialização (`saveGame()` / `loadGame()`).
>
> **Commit:** `feat(save): implement full save/load of game state`

---

## Fase 11 – Orquestração de Turnos Multiplayer (Concluída)
**Objetivo:** Introduzir loop multiplayer autoritativo com turnos sequenciais.
**Arquivos:** `lib/multiplayer/game_socket.dart`, `lib/multiplayer/multiplayer_game.dart`, `lib/ui/hud.dart`

**Prompt sugerido:**
> - Host mantém a ordem de jogadores e valida place/remove/end-turn antes de alterar o estado.
> - Clientes não-host enviam ações ao host pelo WebSocket.
> - Após cada ação aprovada, o host ressincroniza `GameState` e transmite o turno atual.
> - HUD bloqueia controles para quem não está na vez.
>
> **Commit:** `feat(multiplayer): enforce turn order and host-validated actions`

---

## Fase 12 – Testes Automatizados (Pendente)
**Objetivo:** Cobrir regras críticas com testes.
**Arquivos:** `test/`

**Prompt sugerido:**
> Criar testes para lógica de orçamento em `placeAt`, recomputo de métricas, condições de vitória/derrota e (opcional) sequência de turnos no multiplayer.
>
> **Commit:** `test(core): add unit tests for placement and metric logic`

## Fase 13 – Sistema de Territórios e Propriedade de Células (Nova)
**Objetivo:** Separar o grid por jogador, atribuindo propriedade às células e limitando construções por território.  
**Arquivos:** `lib/game/state/game_state.dart`, `lib/game/components/cell.dart`, `lib/game/energy_game.dart`, `lib/ui/hud.dart`

**Prompt sugerido:**
> Implementar o campo `ownerId` em `CellModel` (`int` ou `String`) para representar o dono da célula.  
> Ajustar `placeAt(x, y)` para permitir construir **apenas** em células pertencentes ao jogador atual ou adjacentes às suas.  
> Adicionar destaque visual no grid:  
> - Borda ou cor de fundo indicando a cor do jogador (`Colors.blue`, `Colors.red`, etc.).  
> - Mostrar na HUD o jogador da vez.  
> - Bloquear botões de construção quando o jogador não for o atual.  
> Atualizar o sincronismo multiplayer (`MultiplayerGame`) para incluir o `ownerId` nas mensagens de estado.  
>
> **Commit:** `feat(multiplayer): add cell ownership and territory control system`

---

## Fase 14 – Expansão Territorial e Influência (Nova)
**Objetivo:** Permitir expansão do território e disputa por influência.  
**Arquivos:** `lib/game/energy_game.dart`, `lib/game/state/game_state.dart`, `lib/game/components/cell.dart`

**Prompt sugerido:**
> Criar função `expandTerritory(int centerX, int centerY, int radius, String ownerId)` que marca células ao redor como pertencentes ao jogador.  
> Cada tipo de construção aumenta a influência do jogador:  
> - Solar e Eólica: +energiaLimpa.  
> - Eficiência e Saneamento: +estabilidadeSocial.  
> Introduzir um campo `influence` no `GameState` para cada jogador e uma função `_resolveTerritoryConflicts()` que decide domínio quando duas áreas se sobrepõem.  
> Visualmente, usar um degradê ou contorno misto para indicar zonas em disputa.  
>
> **Commit:** `feat(core): implement territory expansion and influence mechanics`

---

## Fase 15 – Sistema Econômico e Comércio entre Jogadores (Nova)
**Objetivo:** Adicionar economia simples e possibilidade de troca entre jogadores.  
**Arquivos:** `lib/game/state/game_state.dart`, `lib/game/energy_game.dart`, `lib/ui/hud.dart`

**Prompt sugerido:**
> Introduzir novos campos em `GameState`:  
> - `energiaGerada`, `energiaConsumida`, `orcamento`, `saldoComercial`.  
> - Lista `recursos` (por tipo).  
> Implementar um painel de comércio na HUD, permitindo:  
> - Oferecer energia excedente para venda.  
> - Comprar eficiência (custos variáveis por turno).  
> Criar função `tradeWith(String targetId, TradeOffer offer)` para enviar proposta via WebSocket.  
> Atualizar a HUD para exibir indicadores de produção, consumo e exportação com `LinearProgressIndicator`.  
>
> **Commit:** `feat(economy): add trading and resource economy between players`

---

## Fase 16 – Clima Global e Eventos Dinâmicos (Nova)
**Objetivo:** Criar uma camada global de simulação climática e eventos.  
**Arquivos:** `lib/game/world_state.dart`, `lib/game/energy_game.dart`, `lib/ui/hud.dart`

**Prompt sugerido:**
> Criar classe `WorldState` com métricas globais: `temperatura`, `poluicao`, `energiaTotal`, `indiceVerde`.  
> Em `endTurn()`, atualizar o clima com base nas métricas somadas de todos os jogadores.  
> Adicionar eventos aleatórios (tempestades, bônus solares, crises de tarifa) que afetam territórios específicos.  
> Mostrar evento atual na HUD com ícone e descrição (“Tempestade solar aumenta energia limpa por 1 turno”).  
> Possível integração futura com IA: gerar eventos via modelo de narrativa.  
>
> **Commit:** `feat(world): introduce global climate and random event system`

---

## Fase 17 – Ranking e Tipos de Vitória (Nova)
**Objetivo:** Criar condições de vitória múltiplas e ranking final.  
**Arquivos:** `lib/game/state/game_state.dart`, `lib/game/energy_game.dart`, `lib/ui/scoreboard.dart`

**Prompt sugerido:**
> Expandir o sistema de vitória:  
> - **Sustentável:** maior `energiaLimpa` + `acessoEnergia`.  
> - **Econômica:** maior `orcamento` acumulado.  
> - **Científica:** melhor eficiência média.  
> - **Territorial:** maior área controlada.  
> - **Coletiva (opcional):** todos vencem se `climaGlobal` < limiar crítico até o turno final.  
> Criar tela `ScoreboardScreen` exibindo ranking com cores e ícones por tipo de vitória.  
> Adicionar botão “Nova Partida” que reseta todos os dados.  
>
> **Commit:** `feat(gameplay): add victory types and endgame scoreboard`

---

## Observações Gerais
- As fases 13–17 podem ser aplicadas em sprints independentes.  
- As mecânicas devem preservar compatibilidade com o sistema multiplayer atual.  
- Após Fase 17, o jogo passa de **simulação educacional** para **jogo estratégico competitivo**, estilo *Civilization-lite*.  
- Recomenda-se iniciar nova linha de testes automatizados cobrindo território, influência e clima.

---

### 📘 Novo escopo resumido
| Fase | Tema Principal | Tipo de Mudança |
|------|----------------|-----------------|
| 13 | Territórios e propriedade | Estrutural / Visual |
| 14 | Expansão e influência | Estratégica |
| 15 | Economia e comércio | Sistêmica |
| 16 | Clima global e eventos | Simulação |
| 17 | Ranking e vitórias | Gameplay final |

+