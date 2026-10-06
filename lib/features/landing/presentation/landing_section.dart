import 'package:flutter/material.dart';

enum LandingSection {
  about('Sobre', Icons.info_outline_rounded),
  plans('Planos', Icons.workspace_premium_outlined),
  support('Suporte', Icons.support_agent_rounded);

  const LandingSection(this.label, this.icon);

  final String label;
  final IconData icon;
}
