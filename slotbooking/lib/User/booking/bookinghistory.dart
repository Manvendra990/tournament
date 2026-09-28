import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slotbooking/User/navbar/usernavbar.dart';
import 'package:slotbooking/data/theam/app_theam.dart';
import 'package:slotbooking/core/api/api_services.dart';
import 'package:slotbooking/core/api/session_manager.dart';

enum DateFilter { all, today, thisWeek, thisMonth, older }

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});
  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  DateFilter _activeFilter = DateFilter.all;
  late final Future<List<Map<String, dynamic>>> _bookingsFuture;

  String? get _uid => SessionManager.currentUserId;

  static const _green = AppTheme.success;
  static const _greenBg = Color(0xFFDCFCE7);
  static const _greenTxt = Color(0xFF166534);
  static const _redBg = Color(0xFFFEE2E2);
  static const _redTxt = Color(0xFF991B1B);
  static const _amberBg = Color(0xFFFEF3C7);
  static const _amberTxt = Color(0xFF92400E);
  static const _amberBar = Color(0xFFD97706);

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _loadBookings();
  }

  (DateTime?, DateTime?) get _dateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    switch (_activeFilter) {
      case DateFilter.all:
        return (null, null);
      case DateFilter.today:
        return (todayStart, todayEnd);
      case DateFilter.thisWeek:
        final weekStart = todayStart.subtract(
          Duration(days: now.weekday - DateTime.monday),
        );
        return (weekStart, weekStart.add(const Duration(days: 7)));
      case DateFilter.thisMonth:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(
            now.month == 12 ? now.year + 1 : now.year,
            (now.month % 12) + 1,
            1,
          ),
        );
      case DateFilter.older:
        return (null, todayStart);
    }
  }

  Future<List<Map<String, dynamic>>> _loadBookings() async {
    if (_uid == null) return const [];
    return BookingApi().mine();
  }

  List<Map<String, dynamic>> _filterBookings(List<Map<String, dynamic>> rows) {
    final (from, to) = _dateRange;
    if (from == null && to == null) return rows;
    return rows.where((data) {
      final bookingDate = _historyDate(data);
      if (bookingDate == null) return false;
      if (from != null && bookingDate.isBefore(from)) return false;
      if (to != null && !bookingDate.isBefore(to)) return false;
      return true;
    }).toList();
  }

  DateTime? _historyDate(Map<String, dynamic> data) {
    final createdAt = apiDate(data['createdAt']);
    if (createdAt != null) {
      return DateTime(createdAt.year, createdAt.month, createdAt.day);
    }

    final rawDate = data['date']?.toString();
    if (rawDate != null && rawDate.length >= 10) {
      final bookingDate = DateTime.tryParse(rawDate.substring(0, 10));
      if (bookingDate != null) return bookingDate;
    }

    return null;
  }

  Color _statusBarColor(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
        return _green;
      case 'cancelled':
        return AppTheme.error;
      default:
        return _amberBar;
    }
  }

  Color _badgeBg(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
        return _greenBg;
      case 'cancelled':
        return _redBg;
      default:
        return _amberBg;
    }
  }

  Color _badgeTxt(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
        return _greenTxt;
      case 'cancelled':
        return _redTxt;
      default:
        return _amberTxt;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }

  Map<String, List<ApiDocument>> _groupByDate(List<ApiDocument> docs) {
    final groups = <String, List<ApiDocument>>{};
    for (final doc in docs) {
      final data = doc.data();
      final ts = _historyDate(data) ?? DateTime.now();
      groups
          .putIfAbsent(DateFormat('yyyy-MM-dd').format(ts), () => [])
          .add(doc);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildFilterChips(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      bottomNavigationBar: const UserNavBar(currentIndex: 1),
    );
  }

  // ── Header — transaction screen jaisa ─────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: const Text(
              'Booking History',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.lightRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.primaryRed,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips — transaction screen jaisa ───────────────────────────────
  Widget _buildFilterChips() {
    final labels = ['All', 'Today', 'This Week', 'This Month', 'Older'];
    final filters = DateFilter.values;
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final isActive = _activeFilter == filters[i];
            return GestureDetector(
              onTap: () => setState(() => _activeFilter = filters[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primaryRed : AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppTheme.primaryRed
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────
  Widget _buildList() {
    if (_uid == null) {
      return _buildEmpty('Please log in to view bookings', Icons.lock_outline);
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _bookingsFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildEmpty('Error loading bookings.', Icons.error_outline);
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryRed),
          );
        }

        final filteredRows = _filterBookings(
          snap.data ?? const <Map<String, dynamic>>[],
        );
        final docs = filteredRows.map(ApiDocument.new).toList();
        if (docs.isEmpty) {
          return _buildEmpty(
            'No bookings found',
            Icons.calendar_today_outlined,
          );
        }

        final groups = _groupByDate(docs);
        final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

        // Summary counts
        int totalBookings = docs.length;
        int totalSpent = 0;
        for (final doc in docs) {
          final data = doc.data();
          if ((data['paymentStatus'] as String? ?? '') == 'paid') {
            totalSpent += (data['amount'] as num?)?.toInt() ?? 0;
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            _buildSummaryRow(totalBookings, totalSpent),
            ...dates.expand((date) {
              final dayDocs = groups[date]!;
              return [
                // ── Date label ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 28, bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _formatDate(DateTime.parse(date)) == 'Today'
                              ? AppTheme.primaryRed
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(DateTime.parse(date)).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Divider(color: Colors.grey.shade200, height: 1),
                      ),
                    ],
                  ),
                ),
                ...dayDocs.map((doc) => _buildBookingCard(doc.data())),
              ];
            }),
          ],
        );
      },
    );
  }

  // ── Summary row — transaction screen jaisa ────────────────────────────────
  Widget _buildSummaryRow(int total, int spent) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.confirmation_number_outlined,
            iconBg: AppTheme.lightRed,
            iconColor: AppTheme.primaryRed,
            label: 'TOTAL BOOKINGS',
            value: total.toString(),
            valueColor: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.payments_outlined,
            iconBg: _greenBg,
            iconColor: _green,
            label: 'AMOUNT SPENT',
            value: '₹${NumberFormat('#,##,###').format(spent)}',
            valueColor: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Booking card — transaction card jaisa design ──────────────────────────
  Widget _buildBookingCard(Map<String, dynamic> data) {
    final status = data['bookingStatus'] as String? ?? 'pending';
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final groundName = data['groundName'] as String? ?? 'Unknown Ground';
    final slotLabel = data['slotLabel'] as String? ?? '—';
    final rawPayment = data['paymentStatus'] as String? ?? '';
    final statusLabel = status.isNotEmpty
        ? status[0].toUpperCase() + status.substring(1)
        : 'Pending';

    String dateStr = '';
    final createdAt = apiDate(data['createdAt']);
    if (createdAt != null) {
      dateStr = DateFormat('h:mm a').format(createdAt);
    }

    final barColor = _statusBarColor(status);
    final iconBg = _badgeBg(status);
    final iconColor = _badgeTxt(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Colored left bar ───────────────────────────────────────
              Container(width: 4, color: barColor),

              // ── Main content ───────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Icon badge
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.sports_outlined,
                          color: iconColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              groundName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$slotLabel · $dateStr',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Amount + status badge (right aligned)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '-₹$amount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryRed,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _badgeBg(status),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _badgeTxt(status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmpty(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppTheme.lightRed,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppTheme.primaryRed),
          ),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card — transaction screen jaisa ───────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
