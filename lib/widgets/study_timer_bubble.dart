import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../utils/app_theme.dart';

class StudyTimerBubble extends StatelessWidget {
  final VoidCallback onTap;
  const StudyTimerBubble({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(study.formattedTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
