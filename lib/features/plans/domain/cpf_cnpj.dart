/// CPF (pessoa física) e CNPJ (pessoa jurídica) para a cobrança. Confere os
/// dígitos verificadores antes de mandar ao servidor (que confere de novo).
abstract final class CpfCnpj {
  static String digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  static bool isValid(String value) {
    final d = digits(value);
    if (d.length == 11) return _validCpf(d);
    if (d.length == 14) return _validCnpj(d);
    return false;
  }

  /// "123.456.789-09" / "12.345.678/0001-95"; outro tamanho volta como veio.
  static String format(String value) {
    final d = digits(value);
    if (d.length == 11) {
      return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}'
          '-${d.substring(9)}';
    }
    if (d.length == 14) {
      return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}'
          '/${d.substring(8, 12)}-${d.substring(12)}';
    }
    return value;
  }

  static bool _allSame(String d) => d.split('').toSet().length == 1;

  static bool _validCpf(String d) {
    if (_allSame(d)) return false;
    int check(int length) {
      var sum = 0;
      for (var i = 0; i < length; i++) {
        sum += int.parse(d[i]) * (length + 1 - i);
      }
      final rest = (sum * 10) % 11;
      return rest == 10 ? 0 : rest;
    }

    return check(9) == int.parse(d[9]) && check(10) == int.parse(d[10]);
  }

  static bool _validCnpj(String d) {
    if (_allSame(d)) return false;
    int check(List<int> weights) {
      var sum = 0;
      for (var i = 0; i < weights.length; i++) {
        sum += int.parse(d[i]) * weights[i];
      }
      final rest = sum % 11;
      return rest < 2 ? 0 : 11 - rest;
    }

    const w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    const w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    return check(w1) == int.parse(d[12]) && check(w2) == int.parse(d[13]);
  }
}
