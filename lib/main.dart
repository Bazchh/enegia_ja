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
          ],
        ),
      ),
    );
  }
}
