import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/lesson_model.dart';
import '../../models/question_model.dart';

/// Camada de acesso ao Firestore para a feature `lesson`.
///
/// O `LessonRepositoryImpl` depende DESTA classe — não do Firestore
/// diretamente. Isolar o SDK aqui permite:
/// 1. Trocar Firestore por outro backend (REST, GraphQL, etc.) criando
///    uma nova implementação sem tocar em domain/.
/// 2. Mockar o datasource em testes sem precisar de fake_cloud_firestore.
/// 3. Evoluir o schema (de `Phase`/`Questions` flat para
///    `materias/modulos/temas/fases` hierárquico) num único ponto.
class LessonFirestoreDataSource {
  LessonFirestoreDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _phases =>
      _firestore.collection('Phase');

  CollectionReference<Map<String, dynamic>> get _questions =>
      _firestore.collection('Questions');

  Future<List<LessonModel>> fetchAllLessons() async {
    final snap = await _phases.orderBy('order').get();
    final lessons = <LessonModel>[];
    for (final doc in snap.docs) {
      final questions = await _fetchQuestionsForPhase(doc.reference);
      lessons.add(LessonModel.fromSnapshot(doc, questions));
    }
    return lessons;
  }

  Future<LessonModel?> fetchLessonById(String id) async {
    final doc = await _phases.doc(id).get();
    if (!doc.exists) return null;
    final questions = await _fetchQuestionsForPhase(doc.reference);
    return LessonModel.fromSnapshot(doc, questions);
  }

  Future<List<QuestionModel>> _fetchQuestionsForPhase(
    DocumentReference phaseRef,
  ) async {
    final snap =
        await _questions.where('phase_ref', isEqualTo: phaseRef).get();
    return snap.docs.map(QuestionModel.fromSnapshot).toList();
  }
}
