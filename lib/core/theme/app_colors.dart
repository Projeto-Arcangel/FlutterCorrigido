import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── App ─────────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF72ACD0);
  static const Color background = Color(0xFFD9D9D9);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E1F28);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderBlue = Color(0xFF72ACD0);
  static const Color error = Color(0xFFE53935);

  // ── Dark mode ───────────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF1D2428);
  static const Color surfaceDark = Color(0xFF282932);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color socialButton = Color(0xFFF1F4F8);

  // ── Matérias — Ciências Humanas e Sociais ───────────────────────────────────
  static const Color subjectHistory = Color(0xFF6F574A);
  static const Color subjectPhilosophy = Color(0xFFD9D9D9);
  static const Color subjectSociology = Color(0xFFEAD47F);
  static const Color subjectGeography = Color(0xFF72D082);

  // ── Matérias — Linguagens ───────────────────────────────────────────────────
  /// Português — azul-ardósia profundo
  static const Color subjectPortuguese = Color(0xFF4A6FA5);
  /// Artes — rosa queimado vibrante
  static const Color subjectArts = Color(0xFFD45D79);
  /// Ed. Física — verde-lima esportivo
  static const Color subjectPhysEd = Color(0xFF6AB04C);

  // ── Matérias — Ciências da Natureza e Matemática ────────────────────────────
  /// Matemática — âmbar dourado
  static const Color subjectMath = Color(0xFFE8A838);
  /// Biologia — verde-teal
  static const Color subjectBiology = Color(0xFF2ECC71);
  /// Química — lilás-índigo
  static const Color subjectChemistry = Color(0xFF9B59B6);
  /// Física — azul-profundo
  static const Color subjectPhysics = Color(0xFF3498DB);

  // ── Cor do cadeado por matéria ───────────────────────────────────────────────
  static const Color lockOnPhilosophy = Color(0xFF888888);
  static const Color lockOnSociology = Color(0xFF8A7A30);
  static const Color lockOnGeography = Color(0xFF3A7A45);
  static const Color lockOnPortuguese = Color(0xFF2A4A75);
  static const Color lockOnArts = Color(0xFF8A2040);
  static const Color lockOnPhysEd = Color(0xFF3A6A20);
  static const Color lockOnMath = Color(0xFF8A5A10);
  static const Color lockOnBiology = Color(0xFF1A8050);
  static const Color lockOnChemistry = Color(0xFF5A2070);
  static const Color lockOnPhysics = Color(0xFF1A5A90);

  // ── Texto sobre botão de matéria ────────────────────────────────────────────
  static const Color onSubject = Color(0xFF282932);
  /// Para matérias escuras onde o texto precisa ser claro
  static const Color onSubjectLight = Color(0xFFFFFFFF);
}