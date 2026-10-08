/// Falha ao ler um material, com a mensagem pronta para o professor.
class MaterialReadException implements Exception {
  const MaterialReadException(this.message);

  final String message;

  @override
  String toString() => message;
}
