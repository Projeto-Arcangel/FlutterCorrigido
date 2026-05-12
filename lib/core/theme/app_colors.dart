import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // App
  static const Color primary = Color(0xFF72ACD0);
  static const Color background = Color(0xFFD9D9D9);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E1F28);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderBlue = Color(0xFF72ACD0);
  static const Color error = Color(0xFFE53935);

  // Matérias (preservando paleta do FlutterFlow original)
  static const Color subjectHistory = Color(0xFF6F574A);
  static const Color subjectPhilosophy = Color(0xFFD9D9D9);
  static const Color subjectSociology = Color(0xFFEAD47F);
  static const Color subjectGeography = Color(0xFF72D082);

  // Cor do cadeado por matéria
  static const Color lockOnPhilosophy = Color(0xFF888888);
  static const Color lockOnSociology = Color(0xFF8A7A30);
  static const Color lockOnGeography = Color(0xFF3A7A45);

  // Texto sobre botão de matéria
  static const Color onSubject = Color(0xFF282932);
// DEPOIS — adicionar cores do modo escuro
static const Color backgroundDark = Color(0xFF1D2428);
static const Color surfaceDark   = Color(0xFF282932);
static const Color textOnDark    = Color(0xFFFFFFFF);
static const Color socialButton  = Color(0xFFF1F4F8); // botões Google/Facebook
}