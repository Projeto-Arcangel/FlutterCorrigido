/// Nova lista com o item de [oldIndex] movido para [newIndex], no formato
/// que o `ReorderableListView.onReorder` informa: o destino conta o próprio
/// item, então ao mover para baixo ele vem 1 a mais que a posição final.
///
/// Devolve uma lista nova (a original não muda) com os mesmos itens.
List<T> reorderedList<T>(List<T> items, int oldIndex, int newIndex) {
  final result = [...items];
  final item = result.removeAt(oldIndex);
  result.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
  return result;
}
