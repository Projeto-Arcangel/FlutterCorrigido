import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/subject.dart';

/// Lista de matérias disponíveis no app.
final subjectsProvider = Provider<List<Subject>>((_) => Subject.all);

/// Matéria atualmente selecionada (após o usuário tocar em "História").
final selectedSubjectProvider = StateProvider<Subject?>((_) => null);