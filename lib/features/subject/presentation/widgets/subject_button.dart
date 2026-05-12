import 'package:flutter/material.dart';

import '../../domain/entities/subject.dart';

class SubjectButton extends StatelessWidget {
  const SubjectButton({
    super.key,
    required this.subject,
    required this.onTap,
  });

  final Subject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 60,
      child: Material(
        color: subject.color,
        borderRadius: BorderRadius.circular(50),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: subject.unlocked ? onTap : null,
          child: Center(
            child: subject.unlocked
                ? Text(
                    subject.name,
                    style: const TextStyle(
                      color: Color(0xFF282932),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Icon(
                    Icons.lock_outlined,
                    color: subject.lockColor,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}