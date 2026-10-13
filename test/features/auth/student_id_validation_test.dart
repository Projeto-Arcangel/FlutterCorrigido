import 'package:arcangel_o_oficial/features/auth/presentation/widgets/auth_validators.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// O prontuário é a identificação institucional de qualquer instituição:
/// sem formato fixo (antes era o do IFSP, "PT" + 7 dígitos).
void main() {
  String type(String text) {
    // Como o campo faz: cada formatador recebe o resultado do anterior.
    var value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    for (final f in AuthValidators.studentIdFormatters) {
      value = f.formatEditUpdate(TextEditingValue.empty, value);
    }
    return value.text;
  }

  test('aceita identificações de qualquer formato', () {
    for (final id in [
      'PT1234567',
      'SP3012345',
      '2023.1.0456-7',
      'RA 123456',
      'ab12',
      '7',
      'Matrícula 99/2026',
    ]) {
      expect(AuthValidators.studentId(id), isNull, reason: id);
    }
  });

  test('só exige que seja preenchido', () {
    expect(AuthValidators.studentId(''), 'Informe seu prontuário');
    expect(AuthValidators.studentId('   '), 'Informe seu prontuário');
    expect(AuthValidators.studentId(null), 'Informe seu prontuário');
  });

  test('grava em maiúsculas, sem espaços sobrando', () {
    expect(AuthValidators.normalizeStudentId('  ra  2023 001 '), 'RA 2023 001');
    expect(AuthValidators.normalizeStudentId('PT1234567'), 'PT1234567');
    expect(AuthValidators.normalizeStudentId('matrícula 9/ç'), 'MATRÍCULA 9/Ç');
  });

  test('vira maiúscula ao digitar, sem filtrar caracteres; limita o tamanho',
      () {
    expect(type('ra-2023/1.x'), 'RA-2023/1.X');
    expect(type('linha\nquebrada'), 'LINHAQUEBRADA');
    expect(type('A' * 50), hasLength(AuthValidators.studentIdMaxLength));
  });

  test('texto de apoio novo', () {
    expect(
      AuthValidators.studentIdHelp,
      'Insira a sua identificação institucional.',
    );
  });
}
