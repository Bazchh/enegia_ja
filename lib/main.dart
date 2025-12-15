import 'package:flutter/material.dart';
import 'game/energy_game.dart';
import 'ui/game_screen.dart';
import 'ui/multiplayer_menu.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Energia Já!',
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      showPerformanceOverlay: false,
      showSemanticsDebugger: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          // Cores principais
          primary: const Color(0xFFFFB300), // Amarelo/Dourado
          secondary: const Color(0xFFFF6F00), // Laranja elétrico
          tertiary: const Color(0xFFFDD835), // Amarelo claro (accent)

          // Backgrounds
          surface: const Color(0xFF2C2C2C), // Cinza médio (cards)
          surfaceContainerHighest: const Color(0xFF1A1A1A), // Cinza escuro (fundo)

          // Textos
          onPrimary: const Color(0xFF000000), // Preto (em cima do amarelo)
          onSecondary: const Color(0xFF000000), // Preto (em cima do laranja)
          onSurface: const Color(0xFFFFFFFF), // Branco (texto normal)

          // Status
          error: const Color(0xFFFF5252),
        ),
        brightness: Brightness.dark,
        useMaterial3: true,

        // Componentes específicos
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2C2C2C),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          foregroundColor: Color(0xFFFFB300),
          elevation: 0,
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFB300),
            foregroundColor: const Color(0xFF000000),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        cardTheme: CardTheme(
          color: const Color(0xFF2C2C2C),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFFB300)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF444444)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFFB300), width: 2),
          ),
        ),
      ),
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Energia Já!'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const Text(
              'Energia Já!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 50),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GameScreen(game: EnergyGame()),
                  ),
                );
              },
              child: const Text('Modo Individual'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const MultiplayerMenu(),
                  ),
                );
              },
              child: const Text('Modo Multiplayer'),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.help_outline, color: Color(0xFFFFB300)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFFFB300), width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const _HowToPlayDialog(),
                );
              },
              label: const Text(
                'Como Jogar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToPlayDialog extends StatelessWidget {
  const _HowToPlayDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help, color: Color(0xFFFFB300)),
                const SizedBox(width: 12),
                Text(
                  'Como Jogar',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Objetivo: construir energia limpa, equilibrar orçamento e conquistar território antes dos demais.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const _HowToPlayTip(
              title: 'Como começar',
              bullets: [
                'Use seu território inicial para erguer as primeiras usinas.',
                'Solar e eólica são baratas e limpam o mapa rapidamente.',
              ],
            ),
            const _HowToPlayTip(
              title: 'Gerencie o dinheiro',
              bullets: [
                'Cada construção custa orçamento. Planeje antes de gastar.',
                'Edifícios de eficiência e tesouros aumentam sua renda por turno.',
              ],
            ),
            const _HowToPlayTip(
              title: 'Expanda com cuidado',
              bullets: [
                'Construções criam influência e conquistam células vizinhas com o tempo.',
                'Avançar sobre recursos estratégicos dá bônus fortes (dinheiro, energia limpa, pesquisa).',
              ],
            ),
            const _HowToPlayTip(
              title: 'Olho nas vitórias',
              bullets: [
                'Sustentável: mantenha energia limpa alta.',
                'Econômica: tenha o maior orçamento.',
                'Científica: melhore educação e reduza tarifa.',
                'Territorial: controle mais células.',
                'Coletiva: o clima global precisa ficar saudável; todos ganham esse selo.',
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendi!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToPlayTip extends StatelessWidget {
  const _HowToPlayTip({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          ...bullets.map(
            (b) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(b)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
