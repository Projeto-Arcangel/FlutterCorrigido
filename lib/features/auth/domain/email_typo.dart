/// Detecta erros de digitação no domínio dos provedores de e-mail mais comuns
/// ("gmial.com", "hotmail.con", "outlok.com") e sugere a correção.
///
/// Necessário além da checagem de DNS do servidor: muitos domínios com erro
/// de digitação EXISTEM e recebem e-mail (são registrados justamente para
/// capturar esses enganos), então passariam na validação de domínio — e a
/// pessoa nunca receberia o link de confirmação.
abstract final class EmailTypo {
  /// Provedores conferidos (nome, sufixo).
  static const _targets = [
    ('gmail', 'com'),
    ('hotmail', 'com'),
    ('hotmail', 'com.br'),
    ('outlook', 'com'),
    ('outlook', 'com.br'),
    ('yahoo', 'com'),
    ('yahoo', 'com.br'),
    ('icloud', 'com'),
    ('live', 'com'),
  ];

  /// Domínios reais parecidos com os de cima — nunca recebem sugestão.
  static const _realDomains = {
    'mail.com',
    'email.com',
    'ymail.com',
    'gmx.com',
    'me.com',
    'msn.com',
    'aol.com',
    'live.com.br',
    'yahoo.ca',
    'hotmail.ca',
    'hotmail.fr',
    'hotmail.it',
    'hotmail.es',
    'hotmail.de',
    'hotmail.co.uk',
    'live.ca',
    'live.co.uk',
    'outlook.pt',
    'outlook.es',
    'yahoo.co.uk',
    'yahoo.fr',
    'yahoo.es',
    'proton.me',
    'protonmail.com',
    'zoho.com',
  };

  /// E-mail corrigido, ou `null` se o domínio não parece um erro de digitação.
  static String? suggestion(String email) {
    final at = email.lastIndexOf('@');
    if (at <= 0) return null;
    final local = email.substring(0, at);
    final domain = email.substring(at + 1).toLowerCase();
    if (_realDomains.contains(domain)) return null;

    final dot = domain.indexOf('.');
    if (dot <= 0) return null;
    final name = domain.substring(0, dot);
    final suffix = domain.substring(dot + 1);

    for (final (targetName, targetSuffix) in _targets) {
      if (name == targetName && suffix == targetSuffix) return null;
    }

    String? best;
    var bestDistance = 1 << 30;
    for (final (targetName, targetSuffix) in _targets) {
      final int distance;
      if (suffix == targetSuffix) {
        // "gmial.com": nome com erro, sufixo certo. Nomes curtos toleram 1
        // erro; os maiores, 2 (inversão de letras conta como 1).
        distance = _distance(name, targetName);
        if (distance > (targetName.length <= 5 ? 1 : 2)) continue;
      } else if (name == targetName) {
        // "gmail.con": nome certo, sufixo com 1 erro.
        distance = _distance(suffix, targetSuffix);
        if (distance > 1) continue;
      } else {
        continue;
      }
      if (distance < bestDistance) {
        bestDistance = distance;
        best = '$targetName.$targetSuffix';
      }
    }
    return best == null ? null : '$local@$best';
  }

  /// Distância de edição com inversão de letras vizinhas contando como 1
  /// (Damerau–Levenshtein, variante "optimal string alignment").
  static int _distance(String a, String b) {
    final d = List.generate(
      a.length + 1,
      (i) => List<int>.generate(
        b.length + 1,
        (j) => i == 0 ? j : (j == 0 ? i : 0),
      ),
    );
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var best = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        if (i > 1 &&
            j > 1 &&
            a[i - 1] == b[j - 2] &&
            a[i - 2] == b[j - 1] &&
            d[i - 2][j - 2] + 1 < best) {
          best = d[i - 2][j - 2] + 1;
        }
        d[i][j] = best;
      }
    }
    return d[a.length][b.length];
  }
}
