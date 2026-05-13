import 'dart:math';

/// ─────────────────────────────────────────────────────────────────────────────
/// Funções puras de progressão de nível — fonte ÚNICA de verdade.
///
/// Fórmula polinomial (estilo JRPG):
///   XP para avançar do nível N para N+1 = floor(base × N^expoente)
///
/// Parâmetros atuais: base = 80, expoente = 1.5
///   Nível 1 →  80 XP  |  Nível 5 →  894 XP  |  Nível 10 → 2 529 XP
/// ─────────────────────────────────────────────────────────────────────────────

const double _kBase = 80;
const double _kExp = 1.5;

/// XP necessário para avançar do [level] para level + 1.
int xpRequiredForLevel(int level) => (_kBase * pow(level, _kExp)).floor();

/// XP total acumulado necessário para CHEGAR ao [level].
/// Exemplo: `totalXpForLevel(1) == 0` (começa no nível 1 com 0 XP).
///          `totalXpForLevel(2) == 80` (precisa de 80 XP para chegar ao 2).
double totalXpForLevel(int level) {
  double total = 0;
  for (int i = 1; i < level; i++) {
    total += xpRequiredForLevel(i);
  }
  return total;
}

/// Dado o [xp] total acumulado, retorna qual nível o usuário deveria ter.
int levelForXp(double xp) {
  int level = 1;
  while (xp >= totalXpForLevel(level + 1)) {
    level++;
  }
  return level;
}
