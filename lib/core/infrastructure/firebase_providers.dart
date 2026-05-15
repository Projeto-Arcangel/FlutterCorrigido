import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

/// Region precisa casar com a região do deploy das Cloud Functions
/// (`southamerica-east1`). Se divergir, o SDK aponta para us-central1
/// e a chamada retorna 404.
final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instanceFor(region: 'southamerica-east1'),
);
