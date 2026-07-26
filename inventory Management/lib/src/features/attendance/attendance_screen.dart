import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/attendance_provider.dart';
import 'attendance_calendar_dialog.dart';
import '../../core/models/models.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AttendanceScreenContent();
  }
}

class AttendanceScreenContent extends ConsumerStatefulWidget {
  const AttendanceScreenContent({super.key});

  @override
  ConsumerState<AttendanceScreenContent> createState() => AttendanceScreenContentState();
}

class AttendanceScreenContentState extends ConsumerState<AttendanceScreenContent> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, AttendanceRecord> _attendanceStatus = {};
  Map<String, AttendanceRecord>? _lastLoadedMap;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(attendanceProvider.notifier).loadAttendance(_selectedDate));
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      ref.read(attendanceProvider.notifier).loadAttendance(_selectedDate);
    }
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

  void _selectTime(BuildContext context, String employeeId, bool isCheckIn, AttendanceRecord currentRecord) async {
    final initialTimeStr = isCheckIn ? (currentRecord.checkIn ?? '09:00') : (currentRecord.checkOut ?? '18:00');
    final parts = initialTimeStr.split(':');
    final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1B5E20),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _attendanceStatus[employeeId] = AttendanceRecord(
          status: currentRecord.status,
          checkIn: isCheckIn ? formatted : (currentRecord.checkIn ?? '09:00'),
          checkOut: isCheckIn ? (currentRecord.checkOut ?? '18:00') : formatted,
        );
      });
    }
  }

  Widget _buildStatusChip({
    required String status,
    required Color color,
    required String currentStatus,
    required VoidCallback onTap,
  }) {
    final isSelected = currentStatus == status;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCallConfirmationDialog(BuildContext context, String name, String phoneNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_in_talk, color: Color(0xFF1B5E20)),
            SizedBox(width: 8),
            Text('Call Employee', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to call $name at $phoneNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final Uri launchUri = Uri(
                scheme: 'tel',
                path: phoneNumber,
              );
              if (await canLaunchUrl(launchUri)) {
                await launchUrl(launchUri);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch phone dialer')),
                  );
                }
              }
            },
            child: const Text('Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBanner(List<EmployeeProfile> employees) {
    int total = employees.length;
    int present = employees.where((emp) {
      final status = _attendanceStatus[emp.id]?.status ?? 'Absent';
      return status == 'Full Day' || status == 'Half Day';
    }).length;
    int absent = employees.where((emp) {
      final status = _attendanceStatus[emp.id]?.status ?? 'Absent';
      return status == 'Absent';
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', '$total', Colors.blue.shade700),
          Container(height: 32, width: 1, color: Colors.grey.shade200),
          _buildStatItem('Present', '$present', Colors.green.shade700),
          Container(height: 32, width: 1, color: Colors.grey.shade200),
          _buildStatItem('Absent', '$absent', Colors.red.shade700),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);
    final employeesAsync = ref.watch(employeeListProvider);
    final defaultStatus = (_selectedDate.weekday == DateTime.sunday) ? 'Weekly Off' : 'Absent';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              DateFormat('dd MMMM yyyy').format(_selectedDate),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              await ref.read(attendanceProvider.notifier).saveAttendance(_selectedDate, _attendanceStatus);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attendance saved successfully'),
                    backgroundColor: Color(0xFF1B5E20),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: attendanceState.when(
        data: (attendanceMap) {
          if (!identical(_lastLoadedMap, attendanceMap) && !identical(_attendanceStatus, attendanceMap)) {
            _attendanceStatus.clear();
            _attendanceStatus.addAll(attendanceMap);
          }
          _lastLoadedMap = attendanceMap;
          return employeesAsync.when(
            data: (employees) {
              if (employees.isEmpty) {
                return const Center(child: Text('No employees found.'));
              }
              return Column(
                children: [
                  _buildStatsBanner(employees),
                  Expanded(
                    child: ListView.builder(
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        final currentRecord = _attendanceStatus[employee.id] ?? AttendanceRecord(
                          status: defaultStatus,
                          checkIn: defaultStatus == 'Absent' || defaultStatus == 'Weekly Off' ? null : '09:00',
                          checkOut: defaultStatus == 'Absent' || defaultStatus == 'Weekly Off' ? null : '18:00',
                        );
                        
                        final showTimeTracker = currentRecord.status == 'Full Day' || currentRecord.status == 'Half Day';
                        final hours = showTimeTracker ? _calculateHours(currentRecord.checkIn, currentRecord.checkOut) : 0.0;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name and Call button
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      employee.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ),
                                  if (employee.phoneNumber.isNotEmpty) ...[
                                    IconButton(
                                      icon: const Icon(Icons.phone_in_talk, color: Colors.green, size: 20),
                                      onPressed: () => _showCallConfirmationDialog(context, employee.name, employee.phoneNumber),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Subtitle with Tap to history and Phone number
                              Row(
                                children: [
                                  if (employee.phoneNumber.isNotEmpty) ...[
                                    Text(
                                      employee.phoneNumber,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => EmployeeAttendanceCalendarDialog(employee: employee),
                                      );
                                    },
                                    child: const Row(
                                      children: [
                                        Icon(Icons.calendar_month, size: 14, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('History log', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // 4-state Selector Row
                              Row(
                                children: [
                                  _buildStatusChip(
                                    status: 'Full Day',
                                    color: Colors.green,
                                    currentStatus: currentRecord.status,
                                    onTap: () {
                                      setState(() {
                                        _attendanceStatus[employee.id] = AttendanceRecord(
                                          status: 'Full Day',
                                          checkIn: currentRecord.checkIn ?? '09:00',
                                          checkOut: currentRecord.checkOut ?? '18:00',
                                        );
                                      });
                                    },
                                  ),
                                  _buildStatusChip(
                                    status: 'Half Day',
                                    color: Colors.orange,
                                    currentStatus: currentRecord.status,
                                    onTap: () {
                                      setState(() {
                                        _attendanceStatus[employee.id] = AttendanceRecord(
                                          status: 'Half Day',
                                          checkIn: currentRecord.checkIn ?? '09:00',
                                          checkOut: currentRecord.checkOut ?? '13:00',
                                        );
                                      });
                                    },
                                  ),
                                  _buildStatusChip(
                                    status: 'Absent',
                                    color: Colors.red,
                                    currentStatus: currentRecord.status,
                                    onTap: () {
                                      setState(() {
                                        _attendanceStatus[employee.id] = AttendanceRecord(
                                          status: 'Absent',
                                          checkIn: null,
                                          checkOut: null,
                                        );
                                      });
                                    },
                                  ),
                                  _buildStatusChip(
                                    status: 'Weekly Off',
                                    color: Colors.blue.shade700,
                                    currentStatus: currentRecord.status,
                                    onTap: () {
                                      setState(() {
                                        _attendanceStatus[employee.id] = AttendanceRecord(
                                          status: 'Weekly Off',
                                          checkIn: null,
                                          checkOut: null,
                                        );
                                      });
                                    },
                                  ),
                                ],
                              ),
                              
                              // Check-In / Check-Out time selectors if Present
                              if (showTimeTracker) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _selectTime(context, employee.id, true, currentRecord),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('CHECK IN', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.login, size: 14, color: Colors.green),
                                                const SizedBox(width: 6),
                                                Text(
                                                  currentRecord.checkIn ?? '09:00',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _selectTime(context, employee.id, false, currentRecord),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('CHECK OUT', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.logout, size: 14, color: Colors.red),
                                                const SizedBox(width: 6),
                                                Text(
                                                  currentRecord.checkOut ?? '18:00',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${hours.toStringAsFixed(1)} hrs',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20), fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
