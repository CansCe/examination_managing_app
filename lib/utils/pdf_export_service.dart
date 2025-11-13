import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;

class PdfExportService {
  /// Export exam score distribution and student scores to PDF
  static Future<String> exportExamScores({
    required String examTitle,
    required String examSubject,
    required DateTime examDate,
    required String examTime,
    required int examDuration,
    required List<Map<String, dynamic>> studentSessions,
    required List<Map<String, dynamic>> examResults,
  }) async {
    final pdf = pw.Document();

    // Calculate statistics
    final completedResults = examResults.where((r) => r['percentageScore'] != null).toList();
    final totalStudents = studentSessions.length;
    final completedCount = completedResults.length;
    final notCompletedCount = totalStudents - completedCount;

    // Calculate score distribution (0-20, 21-40, 41-60, 61-80, 81-100)
    final distribution = <String, int>{
      '0-20': 0,
      '21-40': 0,
      '41-60': 0,
      '61-80': 0,
      '81-100': 0,
    };

    double totalScore = 0;
    double maxScore = 0;
    double minScore = 100;

    for (final result in completedResults) {
      final percentage = (result['percentageScore'] as num?)?.toDouble() ?? 0.0;
      totalScore += percentage;

      if (percentage > maxScore) maxScore = percentage;
      if (percentage < minScore) minScore = percentage;

      if (percentage >= 0 && percentage <= 20) {
        distribution['0-20'] = (distribution['0-20'] ?? 0) + 1;
      } else if (percentage >= 21 && percentage <= 40) {
        distribution['21-40'] = (distribution['21-40'] ?? 0) + 1;
      } else if (percentage >= 41 && percentage <= 60) {
        distribution['41-60'] = (distribution['41-60'] ?? 0) + 1;
      } else if (percentage >= 61 && percentage <= 80) {
        distribution['61-80'] = (distribution['61-80'] ?? 0) + 1;
      } else if (percentage >= 81 && percentage <= 100) {
        distribution['81-100'] = (distribution['81-100'] ?? 0) + 1;
      }
    }

    final averageScore = completedCount > 0 ? totalScore / completedCount : 0.0;

    // Create a map of studentId to result for quick lookup
    // Handle both ObjectId and string formats
    final resultMap = <String, Map<String, dynamic>>{};
    for (final result in examResults) {
      dynamic studentIdObj = result['studentId'];
      String studentId;
      if (studentIdObj is Map) {
        // If it's an ObjectId from MongoDB, extract the string
        studentId = studentIdObj['\$oid']?.toString() ?? studentIdObj.toString();
      } else {
        studentId = studentIdObj?.toString() ?? '';
      }
      resultMap[studentId] = result;
    }

    // Build PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Exam Score Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    examTitle,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Exam Information
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Exam Information',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Subject: $examSubject'),
                      pw.Text('Duration: $examDuration minutes'),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Date: ${examDate.toString().split(' ')[0]}'),
                      pw.Text('Time: $examTime'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Statistics Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey700),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Statistics Summary',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text(
                            '$totalStudents',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text('Total Students', style: pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            '$completedCount',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green700,
                            ),
                          ),
                          pw.Text('Completed', style: pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Text(
                            '$notCompletedCount',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange700,
                            ),
                          ),
                          pw.Text('Not Completed', style: pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                      if (completedCount > 0)
                        pw.Column(
                          children: [
                            pw.Text(
                              averageScore.toStringAsFixed(1),
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue700,
                              ),
                            ),
                            pw.Text('Average %', style: pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Score Distribution
            if (completedCount > 0) ...[
              pw.Text(
                'Score Distribution',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey700),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    _buildDistributionRow('0-20%', distribution['0-20'] ?? 0, completedCount),
                    pw.SizedBox(height: 8),
                    _buildDistributionRow('21-40%', distribution['21-40'] ?? 0, completedCount),
                    pw.SizedBox(height: 8),
                    _buildDistributionRow('41-60%', distribution['41-60'] ?? 0, completedCount),
                    pw.SizedBox(height: 8),
                    _buildDistributionRow('61-80%', distribution['61-80'] ?? 0, completedCount),
                    pw.SizedBox(height: 8),
                    _buildDistributionRow('81-100%', distribution['81-100'] ?? 0, completedCount),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // Student Scores Table
            pw.Text(
              'Student Scores',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey700),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Student Name',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Roll Number',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Score',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Percentage',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Status',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Data rows
                ...studentSessions.map((session) {
                  final studentId = session['studentId'] as String? ?? '';
                  final result = resultMap[studentId];
                  final studentName = session['studentName'] as String? ?? 'Unknown';
                  final rollNumber = session['studentRollNumber'] as String? ?? '';
                  final status = session['sessionStatus'] as String? ?? 'not_started';

                  String statusText = 'Not Started';
                  PdfColor statusColor = PdfColors.grey700;

                  if (status == 'completed' && result != null) {
                    statusText = 'Completed';
                    statusColor = PdfColors.green700;
                  } else if (status == 'in_progress') {
                    statusText = 'In Progress';
                    statusColor = PdfColors.blue700;
                  } else if (status == 'time_up') {
                    statusText = 'Time Up';
                    statusColor = PdfColors.orange700;
                  } else if (status == 'finished') {
                    statusText = 'Finished';
                    statusColor = PdfColors.grey700;
                  }

                  final score = result?['earnedPoints'] as int? ?? 0;
                  final totalPoints = result?['totalPoints'] as int? ?? 0;
                  final percentage = (result?['percentageScore'] as num?)?.toDouble() ?? 0.0;

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(studentName),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(rollNumber),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          result != null ? '$score/$totalPoints' : '-',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          result != null ? '${percentage.toStringAsFixed(1)}%' : '-',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          statusText,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(color: statusColor),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 20),

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated on: ${DateTime.now().toString().split('.')[0]}',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    // Save PDF to Output/PDF export folder
    final outputDir = await _getOutputDirectory();
    final fileName = 'Exam_${examTitle.replaceAll(RegExp(r'[^\w\s-]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = path.join(outputDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  static pw.Widget _buildDistributionRow(String range, int count, int total) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    final barWidth = percentage * 2; // Scale for visual representation

    return pw.Row(
      children: [
        pw.SizedBox(
          width: 60,
          child: pw.Text(range, style: const pw.TextStyle(fontSize: 10)),
        ),
        pw.Expanded(
          child: pw.Stack(
            children: [
              pw.Container(
                height: 20,
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
              pw.Container(
                width: barWidth,
                height: 20,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          '$count (${percentage.toStringAsFixed(1)}%)',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  static Future<Directory> _getOutputDirectory() async {
    // For development mode, use Output/PDF export folder in project root
    final currentDir = Directory.current;
    final outputDir = Directory(path.join(currentDir.path, 'Output', 'PDF export'));

    // Create directory if it doesn't exist
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    return outputDir;
  }
}

