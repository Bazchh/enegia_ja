import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/energy_game.dart';
import 'hud.dart';

class GameScreen extends StatelessWidget {
  final EnergyGame game;

  const GameScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: game),
          HUD(game: game),
        ],
      ),
    );
  }
}