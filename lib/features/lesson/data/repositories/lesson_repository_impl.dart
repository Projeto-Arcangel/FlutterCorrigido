import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/lesson.dart';
import '../../domain/repositories/lesson_repository.dart';
import '../models/lesson_model.dart';
import '../models/question_model.dart';

class LessonRepositoryImpl implements LessonRepository {
  final FirebaseFirestore _firestore;
  final Logger _logger;

  LessonRepositoryImpl(this._firestore, this._logger);

  CollectionReference<Map<String, dynamic>> get _phases =>
      _firestore.collection('Phase');

  CollectionReference<Map<String, dynamic>> get _questions =>
      _firestore.collection('Questions');

  @override
  Future<Either<Failure, List<Lesson>>> getAllLessons() async {
    try {
      final snap = await _phases.orderBy('order').get();
      final lessons = <Lesson>[];
      for (final doc in snap.docs) {
        final questions = await _fetchQuestionsForPhase(doc.reference);
        lessons.add(LessonModel.fromSnapshot(doc, questions));
      }
      return Right(lessons);
    } catch (e, st) {
      _logger.e('getAllLessons failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar lições'));
    }
  }

  @override
  Future<Either<Failure, Lesson>> getLessonById(String id) async {
    try {
      final doc = await _phases.doc(id).get();
      if (!doc.exists) {
        return const Left(NetworkFailure('Lição não encontrada'));
      }
      final questions = await _fetchQuestionsForPhase(doc.reference);
      return Right(LessonModel.fromSnapshot(doc, questions));
    } catch (e, st) {
      _logger.e('getLessonById failed', error: e, stackTrace: st);
      return const Left(NetworkFailure('Falha ao carregar lição'));
    }
  }

  Future<List<QuestionModel>> _fetchQuestionsForPhase(
    DocumentReference phaseRef,
  ) async {
    final snap = await _questions.where('phase_ref', isEqualTo: phaseRef).get();
    return snap.docs.map(QuestionModel.fromSnapshot).toList();
  }
}