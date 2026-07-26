import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import 'data/attendance_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmployeeAttendanceCalendarDialog extends StatefulWidget {
  final EmployeeProfile employee;

  const EmployeeAttendanceCalendarDialog({super.key, required this.employee});

  @override
  State<EmployeeAttendanceCalendarDialog> createState() => _EmployeeAttendanceCalendarDialogState();
}

class _EmployeeAttendanceCalendarDialogState extends State<EmployeeAttendanceCalendarDialog> {
  static const Color brandGreen = Color(0xFF1B5E20);
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  final Map<DateTime, AttendanceRecord> _attendanceMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid ?? 'dummy_uid')
          .collection('attendance')
          .where('employeeId', isEqualTo: widget.employee.id)
          .get();

      _attendanceMap.clear();
      for (var doc in snapshot.docs) {
        final data = EmployeeAttendanceData.fromFirestore(doc);
        final normalizedDate = DateTime(data.date.year, data.date.month, data.date.day);
        _attendanceMap[normalizedDate] = AttendanceRecord.fromFirestore(data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  AttendanceRecord _getRecordForDay(DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    final existing = _attendanceMap[normalizedDate];
    if (existing != null) return existing;
    
    // Default fallback: Weekly Off on Sundays, Absent on other days (if not in future)
    final isFuture = normalizedDate.isAfter(DateTime.now());
    if (isFuture) {
      return AttendanceRecord(status: 'Weekly Off'); // Don't show absent for future
    }
    final defaultStatus = (normalizedDate.weekday == DateTime.sunday) ? 'Weekly Off' : 'Absent';
    return AttendanceRecord(status: defaultStatus);
  }

  double _calculateHours(String? checkIn, String? checkOut) {
    if (checkIn == null || checkOut == null) return 0.0;
    try {
      final inParts = checkIn.split(':');
      final outParts = checkOut.split(':');
      if (inParts.length < 2 || outParts.length < 2) return 0.0;
      final inHour = int.parse(inParts[0]);
      final inMin = int.parse(inParts[1]);
      final outHour = int.parse(outParts[0]);
      final outMin = int.parse(outParts[1]);
      
      final inTime = DateTime(2000, 1, 1, inHour, inMin);
      final outTime = DateTime(2000, 1, 1, outHour, outMin);
      
      var diff = outTime.difference(inTime);
      if (diff.isNegative) {
        diff = diff + const Duration(hours: 24);
      }
      return diff.inMinutes / 60.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> _exportPdfReport() async {
    final pdf = pw.Document();
    final format = DateFormat('MMMM yyyy');
    final monthStr = format.format(_focusedDay);

    int fullDays = 0;
    int halfDays = 0;
    int absentDays = 0;
    int weeklyOffs = 0;

    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final today = DateTime.now();

    final List<Map<String, dynamic>> reportRows = [];

    for (int i = 1; i <= daysInMonth; i++) {
      final day = DateTime(_focusedDay.year, _focusedDay.month, i);
      if (day.isAfter(today)) continue;

      final record = _getRecordForDay(day);
      if (record.status == 'Full Day') fullDays++;
      if (record.status == 'Half Day') halfDays++;
      if (record.status == 'Absent') absentDays++;
      if (record.status == 'Weekly Off') weeklyOffs++;

      final hours = _calculateHours(record.checkIn, record.checkOut);

      reportRows.add({
        'date': day,
        'status': record.status,
        'checkIn': record.checkIn ?? '-',
        'checkOut': record.checkOut ?? '-',
        'hours': hours > 0 ? '${hours.toStringAsFixed(1)} hrs' : '-',
      });
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('HP Business Manager', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.Text(DateFormat('dd-MMM-yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
                pw.Divider(color: PdfColors.green900, thickness: 1.5),
                pw.SizedBox(height: 20),
                pw.Text('Employee Attendance Summary', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                pw.SizedBox(height: 10),
                pw.Text('Employee Name: ${widget.employee.name}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Report Month: $monthStr', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.SizedBox(height: 20),

                // Summary Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPdfSummaryCard('Full Days', '$fullDays', PdfColors.green800),
                    _buildPdfSummaryCard('Half Days', '$halfDays', PdfColors.orange800),
                    _buildPdfSummaryCard('Absents', '$absentDays', PdfColors.red800),
                    _buildPdfSummaryCard('Weekly Offs', '$weeklyOffs', PdfColors.blue800),
                  ],
                ),
                pw.SizedBox(height: 24),
                pw.Text('Day-by-Day Detailed Log', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                pw.SizedBox(height: 8),

                // Table of days
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(2),
                    2: pw.FlexColumnWidth(2),
                    3: pw.FlexColumnWidth(1.5),
                    4: pw.FlexColumnWidth(1.5),
                    5: pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.green50),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Day', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Status', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Check In', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Check Out', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Duration', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
                      ],
                    ),
                    ...reportRows.map((row) {
                      final status = row['status'] as String;
                      PdfColor txtColor = PdfColors.black;
                      if (status == 'Full Day') txtColor = PdfColors.green900;
                      if (status == 'Half Day') txtColor = PdfColors.orange900;
                      if (status == 'Absent') txtColor = PdfColors.red900;
                      if (status == 'Weekly Off') txtColor = PdfColors.blue900;

                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(DateFormat('dd-MMM-yyyy').format(row['date'] as DateTime), style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(DateFormat('EEEE').format(row['date'] as DateTime), style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(status, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: txtColor)),
                          ),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(row['checkIn'] as String, style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(row['checkOut'] as String, style: const pw.TextStyle(fontSize: 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(row['hours'] as String, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${widget.employee.name}_attendance_${DateFormat('yyyy_MM').format(_focusedDay)}.pdf',
    );
  }

  pw.Widget _buildPdfSummaryCard(String label, String val, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: color, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(val, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget? _buildCalendarDay(BuildContext context, DateTime day) {
    final normalizedDate = DateTime(day.year, day.month, day.day);
    final record = _getRecordForDay(day);
    final status = record.status;
    
    Color color;
    if (status == 'Full Day') {
      color = Colors.green.shade700;
    } else if (status == 'Half Day') {
      color = Colors.orange.shade700;
    } else if (status == 'Weekly Off') {
      color = Colors.blue.shade700;
    } else {
      // Future days shouldn't show red
      if (normalizedDate.isAfter(DateTime.now())) {
        return null;
      }
      color = Colors.red.shade700;
    }
    
    final isSelected = isSameDay(_selectedDay, day);
    final isToday = isSameDay(DateTime.now(), day);

    return Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected 
            ? color.withValues(alpha: 0.25) 
            : (isToday ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.12)),
        border: Border.all(
          color: color, 
          width: isSelected ? 2.5 : 1.5,
        ),
        shape: BoxShape.circle,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: color, 
          fontWeight: FontWeight.bold,
          fontSize: isSelected ? 15 : 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int fullDays = 0;
    int halfDays = 0;
    int absentDays = 0;
    int weeklyOffs = 0;

    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final today = DateTime.now();

    for (int i = 1; i <= daysInMonth; i++) {
      final day = DateTime(_focusedDay.year, _focusedDay.month, i);
      if (day.isAfter(today)) continue;

      final record = _getRecordForDay(day);
      if (record.status == 'Full Day') fullDays++;
      if (record.status == 'Half Day') halfDays++;
      if (record.status == 'Absent') absentDays++;
      if (record.status == 'Weekly Off') weeklyOffs++;
    }

    final selectedRecord = _selectedDay != null ? _getRecordForDay(_selectedDay!) : null;
    final selectedHours = selectedRecord != null ? _calculateHours(selectedRecord.checkIn, selectedRecord.checkOut) : 0.0;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: brandGreen)),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: brandGreen, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.employee.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const Text(
                                'Attendance History',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Calendar
                    TableCalendar(
                      firstDay: DateTime(2023),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: brandGreen),
                        leftChevronIcon: Icon(Icons.chevron_left, color: brandGreen),
                        rightChevronIcon: Icon(Icons.chevron_right, color: brandGreen),
                      ),
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Color(0xFFC8E6C9), // Light green
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: TextStyle(color: brandGreen, fontWeight: FontWeight.bold),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) => _buildCalendarDay(context, day),
                        todayBuilder: (context, day, focusedDay) => _buildCalendarDay(context, day),
                        selectedBuilder: (context, day, focusedDay) => _buildCalendarDay(context, day),
                        outsideBuilder: (context, day, focusedDay) => _buildCalendarDay(context, day),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Selected Day Details Panel
                    if (_selectedDay != null && selectedRecord != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Details for ${DateFormat('dd MMM yyyy').format(_selectedDay!)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: brandGreen),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Status: ${selectedRecord.status}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                if (selectedHours > 0)
                                  Text('Hours: ${selectedHours.toStringAsFixed(1)} hrs', style: const TextStyle(fontWeight: FontWeight.bold, color: brandGreen, fontSize: 13)),
                              ],
                            ),
                            if (selectedRecord.checkIn != null && selectedRecord.checkOut != null) ...[
                              const SizedBox(height: 4),
                              Text('Check In: ${selectedRecord.checkIn}   |   Check Out: ${selectedRecord.checkOut}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Monthly Summary Panel
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Summary for ${DateFormat('MMMM yyyy').format(_focusedDay)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSummaryCard('Full', '$fullDays', Colors.green),
                              _buildSummaryCard('Half', '$halfDays', Colors.orange),
                              _buildSummaryCard('Absent', '$absentDays', Colors.red),
                              _buildSummaryCard('Off', '$weeklyOffs', Colors.blue.shade700),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _attendanceMap.keys.any((d) => d.year == _focusedDay.year && d.month == _focusedDay.month)
                                ? _exportPdfReport
                                : null,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
