Integracao de Metodos Formais
=============================

Este registro conecta os requisitos do jogo Energia Ja com os pontos do codigo que sustentam cada invariante. Ele complementa o material de especificacao em `_artefatos/plano_formal/plano_formal.pdf` e serve de ponte entre o plano formal, os testes automatizados e as implementacoes previstas nas fases 13 a 17.

Objetivos e Rastreamento
------------------------
- Plano formal: modelar no documento TLA+, Alloy ou ferramenta equivalente os estados e transicoes descritos abaixo.
- Codigo: validar que cada transicao respeita as invariantes listadas.
- Testes (Fase 12+): derivar casos positivos e negativos para cada requisito.

Invariantes de Estado
---------------------
- Turno monotono: `state.turno` inicia em 1 e apenas cresce enquanto o jogo nao acabou (`lib/game/state/game_state.dart:171`, `lib/game/energy_game.dart:232`).
- Orcamento nunca negativo: nenhuma construcao ocorre se o jogador nao tiver saldo (`lib/game/energy_game.dart:216`), e reembolsos devolvem credito ao dono correto (`lib/game/energy_game.dart:196`).
- Grade consistente: operacoes que manipulam celulas sempre checam limites (`lib/game/energy_game.dart:182`, `lib/game/energy_game.dart:347`) e preservam o tamanho definido em `GameState` (`lib/game/state/game_state.dart:158`).
- Serializacao total: `GameState.toJson` e `GameState.fromJson` mantem todos os campos de estado, incluindo grade, jogadores e metricas (`lib/game/state/game_state.dart:184`, `lib/game/state/game_state.dart:126`), garantindo que `saveGame` e `loadGame` reconstruam um estado valido (`lib/game/energy_game.dart:436`).

Territorio e Propriedade (Fases 13-14)
--------------------------------------
- Controle por dono: apenas o proprietario atual, ou quem ainda nao possui territorio, pode manipular a celula (`lib/game/energy_game.dart:362`).
- Expansao adjacente: novas aquisicoes exigem adjacencia com territorio proprio quando o jogador ja possui celulas (`lib/game/energy_game.dart:376`).
- Remocao segura: remover construcao de outro jogador e vedado (`lib/game/energy_game.dart:188`), preservando integridade de propriedade.

Metricas e Economia (Fases 15-16 em planejamento)
-------------------------------------------------
- Metricas limitadas: `_recomputeMetrics` garante valores em [0, 1] e deriva tarifas a partir de fontes limpas ou sujas (`lib/game/energy_game.dart:247`).
- Bonus deterministas: ganhos de fim de turno dependem apenas de celulas de eficiencia (`lib/game/energy_game.dart:239`), facilitando modelagem formal de economia.
- Estado global previsto: futuras classes de clima e eventos devem manter invariantes similares (placeholder no plano formal).

Multiplayer e Sincronizacao
---------------------------
- Identificacao do jogador local: `setLocalPlayer` sempre registra o jogador antes de qualquer acao (`lib/game/energy_game.dart:56`).
- Estado por jogador: `GameState.ensurePlayer` cria `PlayerState` sob demanda, mantendo o mapa consistente (`lib/game/state/game_state.dart:138`).
- Persistencia deterministica: ao carregar estados antigos sem bloco `players`, o jogo adapta orcamento de forma previsivel (`lib/game/energy_game.dart:450`), requisito que deve constar na especificacao.

Proximos Passos
---------------
- Extrair do plano formal um modelo reduzido (grade 3x3) para validar disputas de territorio e turnos simultaneos.
- Criar a bateria inicial de testes unitarios e integrados cobrindo os cenarios descritos.
- Atualizar este documento conforme novas invariantes surgirem nas fases 15-17.
