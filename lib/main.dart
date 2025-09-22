import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'game/energy_game.dart';
import 'ui/hud.dart';

void main() {
  final game = EnergyGame();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF1565C0), useMaterial3: true),
    home: Stack(
      children: [
        GameWidget(game: game),
        HUD(game: game),
      ],
    ),
  ));
}
