import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../utils/app_theme.dart';
import '../screens/courses/course_detail_screen.dart';

class CourseCard extends StatelessWidget {
  final CourseModel course;
  final bool isAr, isSide;
  const CourseCard({super.key, required this.course, required this.isAr, this.isSide = false});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMain = !isSide;
    final color  = isSide
        ? AppTheme.accentColor
        : AppTheme.primaryColor;

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course, isAr: isAr))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1730) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18), width: 1.2),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // Icon
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: isSide
                  ? [AppTheme.accentColor, Colors.deepOrange]
                  : [AppTheme.primaryColor, AppTheme.secondaryColor]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(isSide ? Icons.extension_rounded : Icons.menu_book_rounded,
                color: Colors.white),
          ),
          const SizedBox(width: 12),
          // Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course title
                Text(isAr ? course.titleAr : course.titleEn,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                // Doctor name
                Text(course.doctorName,
                    style: TextStyle(
                        color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                // For main courses: show university · faculty · year
                if (isMain) ...{
                  const SizedBox(height: 3),
                  Text(
                    [
                      isAr ? course.universityAr : course.universityEn,
                      isAr ? course.facultyAr : course.facultyEn,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  if (course.year > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isAr ? 'السنة ${course.year}' : 'Year ${course.year}',
                            style: TextStyle(
                                color: color, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ]),
                    ),
                },
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
        ]),
      ),
    );
  }
}
