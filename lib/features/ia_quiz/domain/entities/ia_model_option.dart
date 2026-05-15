/// Modelos de IA que o professor pode escolher para gerar questões.
///
/// O valor de [key] casa exatamente com a whitelist `ALLOWED_MODELS`
/// em `firebase/functions/openrouter.js`. Adicionar um modelo aqui
/// sem espelhar no backend faz o backend rejeitar a chamada.
enum IaModelOption {
  geminiFlash(
    key: 'gemini-flash',
    label: 'Gemini Flash',
    description: 'Rápido e versátil — recomendado',
  ),
  gptMini(
    key: 'gpt-mini',
    label: 'GPT Mini',
    description: 'Boa para questões com raciocínio',
  ),
  claudeHaiku(
    key: 'claude-haiku',
    label: 'Claude Haiku',
    description: 'Explicações pedagógicas mais ricas',
  );

  const IaModelOption({
    required this.key,
    required this.label,
    required this.description,
  });

  final String key;
  final String label;
  final String description;

  /// Modelo padrão quando o professor não escolhe nada.
  static const IaModelOption defaultOption = IaModelOption.geminiFlash;

  /// Resolve um [IaModelOption] a partir da [key] vinda do backend.
  /// Retorna null se a key não casa com nenhum.
  static IaModelOption? fromKey(String? key) {
    if (key == null) return null;
    for (final option in IaModelOption.values) {
      if (option.key == key) return option;
    }
    return null;
  }
}
