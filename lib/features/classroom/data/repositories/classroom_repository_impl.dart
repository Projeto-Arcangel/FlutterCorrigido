import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/classroom.dart';
import '../../domain/repositories/classroom_repository.dart';
import '../models/classroom_model.dart';

class ClassroomRepositoryImpl implements ClassroomRepository {
  ClassroomRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Either<Failure, Classroom>> joinByCode({
    required String code,
    required String userId,
  }) async {
    try {
      // 1. Busca a turma pelo código
      final query = await _firestore
          .collection('Classrooms')
          .where('code', isEqualTo: code.trim().toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return const Left(ValidationFailure('Código inválido. Turma não encontrada.'));
      }

      final classroom = ClassroomModel.fromSnapshot(query.docs.first);

      // 2. Adiciona o classroomId ao array do usuário (merge seguro)
      await _firestore.collection('Users').doc(userId).set(
        {
          'classrooms': FieldValue.arrayUnion([classroom.id]),
        },
        SetOptions(merge: true),
      );

      return Right(classroom);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Erro ao entrar na turma.'));
    } catch (_) {
      return const Left(UnknownFailure('Erro inesperado ao entrar na turma.'));
    }
  }

  @override
  Future<Either<Failure, List<Classroom>>> getUserClassrooms(String userId) async {
    try {
      final userSnap = await _firestore.collection('Users').doc(userId).get();
      if (!userSnap.exists) return const Right([]);

      final ids = List<String>.from(
        (userSnap.data()?['classrooms'] as List<dynamic>?) ?? [],
      );
      if (ids.isEmpty) return const Right([]);

      // Firestore limita whereIn a 30 itens — suficiente para turmas
      final snaps = await _firestore
          .collection('Classrooms')
          .where(FieldPath.documentId, whereIn: ids)
          .get();

      final classrooms = snaps.docs
          .map(ClassroomModel.fromSnapshot)
          .toList();

      return Right(classrooms);
    } on FirebaseException catch (e) {
      return Left(NetworkFailure(e.message ?? 'Erro ao carregar turmas.'));
    } catch (_) {
      return const Left(UnknownFailure('Erro inesperado.'));
    }
  }
}