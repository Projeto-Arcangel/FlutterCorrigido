import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arcangel_o_oficial/firebase_options.dart';

void main() {
  test('Test Firestore classroom query', () async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    try {
      final snap = await FirebaseFirestore.instance.collection('Classrooms').limit(1).get();
      print('Docs count: ${snap.docs.length}');
      if (snap.docs.isNotEmpty) {
        print('First doc code: ${snap.docs.first.data()['code']}');
      }
    } catch (e, st) {
      print('Error: $e\n$st');
    }
  });
}
