import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/providers/activity_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_notifier.dart';
import '../../core/auth/security_helper.dart';
import '../stock/stock_screen.dart';
import '../stock/stock_detail_screen.dart';
import '../expenses/expenses_screen.dart';
import '../salary/salary_screen.dart';
import '../attendance/attendance_screen.dart';
import '../chat/chat_screen.dart';
import '../transport/transport_screen.dart';
import '../stock/data/stock_provider.dart';
import '../expenses/data/expense_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _onBottomNavTapped(int index) {
    if (index == _selectedNavIndex) return;
    switch (index) {
      case 0:
        setState(() => _selectedNavIndex = 0);
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StockScreen()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensesScreen()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalaryScreen()));
        break;
      case 4:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.bgColor,
      
      // Top AppBar (InvTrack Pro Header)
      appBar: AppBar(
        elevation: 0,
        backgroundColor: (isDark ? AppTheme.darkSurfaceColor : Colors.white).withValues(alpha: 0.9),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryBlue, size: 22),
            ),
            const SizedBox(width: 10),
            Text(
              "InvTrack Pro",
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: AppTheme.onSurfaceVariant,
            ),
            onPressed: () => setState(() => themeNotifier.toggle()),
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
                        icon: const Icon(Icons.history_rounded, color: AppTheme.onSurfaceVariant),
                        onPressed: () {
                          ref.read(lastSeenActivityProvider.notifier).markAsSeen();
                          _showHistoryBottomSheet(context, ref);
                        },
                      ),
                      if (showDot)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.errorRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => IconButton(
                  icon: const Icon(Icons.history_rounded, color: AppTheme.onSurfaceVariant),
                  onPressed: () => _showHistoryBottomSheet(context, ref),
                ),
                error: (_, __) => IconButton(
                  icon: const Icon(Icons.history_rounded, color: AppTheme.onSurfaceVariant),
                  onPressed: () => _showHistoryBottomSheet(context, ref),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAlignment.start,
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAlignment.start,
                  children: [
                    Text(
                      "Analytics Overview",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Real-time performance tracking for Warehouse Alpha",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryBlue),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM dd, yyyy').format(DateTime.now()),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bento Grid Stat Cards
            Consumer(
              builder: (context, ref, child) {
                final stockAsync = ref.watch(stockItemsProvider);
                final expenseAsync = ref.watch(expenseListProvider);

                int totalItems = 0;
                int lowStockCount = 0;
                double totalExpensesThisMonth = 0.0;

                stockAsync.whenData((items) {
                  totalItems = items.length;
                  lowStockCount = items.where((i) => i.currentQuantity <= 5).length;
                });

                expenseAsync.whenData((expenses) {
                  final now = DateTime.now();
                  for (var e in expenses) {
                    if (e.date.month == now.month && e.date.year == now.year) {
                      totalExpensesThisMonth += e.amount;
                    }
                  }
                });

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        // Total Expenses Card
                        SizedBox(
                          width: isWide ? (constraints.maxWidth / 3) - 10 : (constraints.maxWidth / 2) - 6,
                          child: _bentoStatCard(
                            title: "Monthly Expense",
                            value: "₹${totalExpensesThisMonth.toStringAsFixed(0)}",
                            subtitle: "Current Month Total",
                            icon: Icons.payments_rounded,
                            badgeText: "Expenses",
                            badgeColor: AppTheme.secondaryContainer,
                            badgeTextColor: AppTheme.primaryBlue,
                            iconColor: AppTheme.primaryBlue,
                          ),
                        ),
                        // Total Active Products Card
                        SizedBox(
                          width: isWide ? (constraints.maxWidth / 3) - 10 : (constraints.maxWidth / 2) - 6,
                          child: _bentoStatCard(
                            title: "Total Products",
                            value: "$totalItems",
                            subtitle: "Catalog Total",
                            icon: Icons.inventory_2_rounded,
                            badgeText: "Active",
                            badgeColor: AppTheme.tertiaryFixed.withValues(alpha: 0.3),
                            badgeTextColor: AppTheme.tertiaryGreen,
                            iconColor: AppTheme.tertiaryGreen,
                          ),
                        ),
                        // Low Stock Alert Card
                        SizedBox(
                          width: isWide ? (constraints.maxWidth / 3) - 10 : constraints.maxWidth,
                          child: _bentoStatCard(
                            title: "Low Stock Alerts",
                            value: "$lowStockCount items",
                            subtitle: lowStockCount > 0 ? "Requires restock" : "All stocks healthy",
                            icon: Icons.warning_amber_rounded,
                            badgeText: lowStockCount > 0 ? "Action Required" : "Optimal",
                            badgeColor: lowStockCount > 0 ? AppTheme.errorContainer : AppTheme.tertiaryFixed.withValues(alpha: 0.3),
                            badgeTextColor: lowStockCount > 0 ? AppTheme.errorRed : AppTheme.tertiaryGreen,
                            iconColor: lowStockCount > 0 ? AppTheme.errorRed : AppTheme.tertiaryGreen,
                            isWarning: lowStockCount > 0,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // Quick Actions Block
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  Text(
                    "Quick Actions",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.1,
                    children: [
                      _quickActionButton(
                        icon: Icons.add_box_rounded,
                        label: "Add Product",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StockDetailScreen()),
                        ),
                      ),
                      _quickActionButton(
                        icon: Icons.receipt_long_rounded,
                        label: "Record Expense",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                        ),
                      ),
                      _quickActionButton(
                        icon: Icons.how_to_reg_rounded,
                        label: "Attendance",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                        ),
                      ),
                      _quickActionButton(
                        icon: Icons.groups_rounded,
                        label: "Salary/Staff",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SalaryScreen()),
                        ),
                      ),
                      _quickActionButton(
                        icon: Icons.local_shipping_rounded,
                        label: "Transport",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TransportScreen()),
                        ),
                      ),
                      _quickActionButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: "Messages",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Activity Feed
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.tertiaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Live Activity Feed",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _showHistoryBottomSheet(context, ref),
                        child: Text(
                          "View All",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Consumer(
                    builder: (context, ref, child) {
                      final activities = ref.watch(activityLogsProvider);
                      return activities.when(
                        data: (logs) {
                          if (logs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: Text(
                                  "No recent activity logged",
                                  style: GoogleFonts.inter(color: AppTheme.outline),
                                ),
                              ),
                            );
                          }
                          final recentLogs = logs.take(4).toList();
                          return Column(
                            children: recentLogs.map((log) => _activityFeedTile(log)).toList(),
                          );
                        },
                        loading: () => const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        )),
                        error: (_, __) => const SizedBox(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedNavIndex,
          onTap: _onBottomNavTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: AppTheme.secondary,
          selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups_rounded),
              label: 'Payroll',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_rounded),
              activeIcon: Icon(Icons.access_time_filled_rounded),
              label: 'Attendance',
            ),
          ],
        ),
      ),
    );
  }

  Widget _bentoStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required Color iconColor,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? AppTheme.errorRed.withValues(alpha: 0.3) : AppTheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isWarning ? AppTheme.errorRed : AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityFeedTile(dynamic log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Text(
                  log.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${log.moduleName} • ${DateFormat('hh:mm a').format(log.timestamp)}",
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.outline,
                  ),
                ),
              ],
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
            backgroundColor: AppTheme.errorRed,
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
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

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
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Recent Activities",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_sweep, color: AppTheme.errorRed),
                              tooltip: 'Clear all history',
                              onPressed: () => _showClearAllHistoryDialog(context, ref),
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month, color: AppTheme.primaryBlue),
                              tooltip: 'Filter by date',
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDateFilter ?? DateTime.now(),
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => selectedDateFilter = picked);
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
                              'Filtered: ${DateFormat('dd MMM yyyy').format(selectedDateFilter!)}',
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            backgroundColor: AppTheme.primaryBlue,
                            deleteIconColor: Colors.white,
                            onDeleted: () => setState(() => selectedDateFilter = null),
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
                                child: Text("No activity logs found", style: GoogleFonts.inter(color: AppTheme.outline)),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredLogs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final log = filteredLogs[index];
                                return ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: AppTheme.secondaryContainer,
                                    child: Icon(Icons.history, color: AppTheme.primaryBlue, size: 20),
                                  ),
                                  title: Text(log.description, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                  subtitle: Text("${log.moduleName} • ${DateFormat('dd MMM hh:mm a').format(log.timestamp)}", style: GoogleFonts.inter(fontSize: 12)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
                                    onPressed: () => _showDeleteHistoryDialog(context, ref, log.id),
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
}
     ),
    );
  }
}
