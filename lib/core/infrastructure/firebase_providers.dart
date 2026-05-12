import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provedores globais de Firebase.
///
/// Fica em `core/infrastructure` porque são dependências de plataforma
/// — qualquer feature que precise consultar o Firestore deve importar
/// daqui, não declarar a sua própria instância. Isso facilita testes
/// (override em `ProviderScope`) e impede que cada feature crie sua
/// própria referência divergente.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
