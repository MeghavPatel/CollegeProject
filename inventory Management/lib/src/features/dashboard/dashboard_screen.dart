import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hp/src/features/attendance/attendance_screen.dart';
import '../../core/providers/activity_provider.dart';
import '../../core/theme/theme_notifier.dart';
import '../salary/salary_screen.dart';
import '../expenses/expenses_screen.dart';
import '../transport/transport_screen.dart';
import '../stock/stock_screen.dart';
import '../chat/chat_screen.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/auth/security_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF1B5E20);
    final bgOffWhite = Theme.of(context).scaffoldBackgroundColor;
    final isDark = themeNotifier.isDark;

    return Scaffold(
      backgroundColor: bgOffWhite,

      // 🔹 CLEAN MINIMAL APP BAR
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Row(
          children: [
            // Dark mode toggle button
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: brandGreen,
              ),
              onPressed: () {
                setState(() {
                  themeNotifier.toggle();
                });
              },
            ),
            const Expanded(
              child: Text(
                "HP MANAGER",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 48), // Balance the left icon
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final latestActivity = ref.watch(latestActivityProvider);
              final lastSeen = ref.watch(lastSeenActivityProvider);

              return latestActivity.when(
                data: (activity) {
                  final bool showDot = activity != null &&
                      (lastSeen == null || activity.timestamp.isAfter(lastSeen));

                  return Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.history_rounded, color: Theme.of(context).colorScheme.onSurface),
                        onPressed: () {
                          ref.read(lastSeenActivityProvider.notifier).markAsSeen();
                          _showHistoryBottomSheet(context, ref);
                        },
                      ),
                      if (showDot)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 8,
                              minHeight: 8,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => IconButton(
                  icon: Icon(Icons.history_rounded, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () {
                    ref.read(lastSeenActivityProvider.notifier).markAsSeen();
                    _showHistoryBottomSheet(context, ref);
                  },
                ),
                error: (err, stack) => IconButton(
                  icon: Icon(Icons.history_rounded, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () {
                    ref.read(lastSeenActivityProvider.notifier).markAsSeen();
                    _showHistoryBottomSheet(context, ref);
                  },
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // 🔹 MODERN HEADER (NO APPBAR COLOR)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: brandGreen,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: brandGreen.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome Back 👋",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Business Overview",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // 🔹 GRID MENU
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _menuCard(
                    context,
                    title: "Employees",
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF2E7D32),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SalaryScreen()),
                    ),
                  ),
                  _menuCard(
                    context,
                    title: "Expenses",
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFFC62828),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ExpensesScreen()),
                    ),
                  ),
                  _menuCard(
                    context,
                    title: "Transport",
                    icon: Icons.local_shipping_rounded,
                    color: const Color(0xFF1565C0),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TransportScreen()),
                    ),
                  ),
                  _menuCard(
                    context,
                    title: "Stock",
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFFEF6C00),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StockScreen()),
                    ),
                  ),
                  _menuCard(
                    context,
                    title: "Messages",
                    icon: Icons.forum_rounded,
                    color: const Color(0xFF00695C),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatScreen()),
                    ),
                  ),
                   _menuCard(
                    context,
                    title: "Attendance",
                    icon: Icons.person_pin_circle_rounded,
                    color: const Color(0xFF8E44AD),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AttendanceScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteHistoryDialog(BuildContext context, WidgetRef ref, String logId) async {
    final verified = await showPasswordVerificationDialog(context);
    if (verified) {
      ref.read(activityProvider.notifier).deleteActivity(logId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity log deleted successfully'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showClearAllHistoryDialog(BuildContext context, WidgetRef ref) async {
    final verified = await showPasswordVerificationDialog(context);
    if (verified) {
      ref.read(activityProvider.notifier).deleteAllActivities();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All activity logs cleared successfully'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // 🔹 NEW HISTORY UI (Rupee Icon & Green Cards)
  void _showHistoryBottomSheet(BuildContext context, WidgetRef ref) {
    DateTime? selectedDateFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Recent Activities",
                          style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                              tooltip: 'Clear all history',
                              onPressed: () => _showClearAllHistoryDialog(context, ref),
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month, color: Color(0xFF1B5E20)),
                              tooltip: 'Filter by date',
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDateFilter ?? DateTime.now(),
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() {
                                    selectedDateFilter = picked;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (selectedDateFilter != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                      child: Row(
                        children: [
                          InputChip(
                            label: Text(
                              'Filtered by: ${DateFormat('dd MMM yyyy').format(selectedDateFilter!)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: const Color(0xFF1B5E20),
                            deleteIconColor: Colors.white,
                            onDeleted: () {
                              setState(() {
                                selectedDateFilter = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final activities = ref.watch(activityLogsProvider);
                        return activities.when(
                          data: (logs) {
                            final filteredLogs = selectedDateFilter == null
                                ? logs
                                : logs.where((log) {
                                    return log.timestamp.year == selectedDateFilter!.year &&
                                        log.timestamp.month == selectedDateFilter!.month &&
                                        log.timestamp.day == selectedDateFilter!.day;
                                  }).toList();

                            if (filteredLogs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history_toggle_off, 
                                      size: 60, 
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      selectedDateFilter == null
                                          ? "No recent updates"
                                          : "No updates on this day",
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                                      )
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              itemCount: filteredLogs.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final log = filteredLogs[index];
                                
                                // 🔹 ICON LOGIC (Fixed Rupee)
                                IconData iconData = Icons.info_outline;
                                Color iconColor = const Color(0xFF1B5E20);
                                
                                if (log.moduleName.contains("Salary") || log.moduleName.contains("Employee")) {
                                  iconData = Icons.currency_rupee;
                                  iconColor = const Color(0xFF2E7D32);
                                } else if (log.moduleName.contains("Stock")) {
                                  iconData = Icons.inventory_2;
                                  iconColor = const Color(0xFFEF6C00);
                                } else if (log.moduleName.contains("Transport")) {
                                  iconData = Icons.local_shipping;
                                  iconColor = const Color(0xFF1565C0);
                                } else if (log.moduleName.contains("Expense")) {
                                  iconData = Icons.account_balance_wallet;
                                  iconColor = const Color(0xFFC62828);
                                } else if (log.moduleName.contains('Chat')) {
                                  iconData = Icons.forum;
                                  iconColor = const Color(0xFF00695C);
                                }

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: const Border(
                                      left: BorderSide(
                                        color: Color(0xFF1B5E20),
                                        width: 5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Icon
                                      Icon(iconData, color: iconColor, size: 28),
                                      
                                      const SizedBox(width: 16),
                                      
                                      // Texts
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              log.moduleName.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF2E7D32),
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              log.description,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              DateFormat('hh:mm a • dd MMM').format(log.timestamp),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Delete Button
                                      InkWell(
                                        onTap: () => _showDeleteHistoryDialog(context, ref, log.id),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => Center(child: Text("Error: $err")),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🔹 PREMIUM CARD
  Widget _menuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      elevation: 6,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
