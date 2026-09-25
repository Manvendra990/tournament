import 'package:slotbookingadmin/core/api/api_compat.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:slotbookingadmin/Admin/navbar/adminNavbar.dart';
import 'package:slotbookingadmin/theme/app_colors.dart';

class AdminRevenueScreen extends StatefulWidget {
  final String adminId;
  const AdminRevenueScreen({super.key, required this.adminId});

  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen>
    with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
  String? _selectedGroundId;
  String? _selectedGroundName;
  late TabController _tabController;

  static const _primary = AppColors.primary;
  static const _gold = Color(0xFFFFB300);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<ApiQuerySnapshot> get _txStream => AdminApiCompat.revenue(date: _selectedDate, groundId: _selectedGroundId);
  Stream<ApiQuerySnapshot> get _allTxStream => AdminApiCompat.revenue();

  void _clearFilters() => setState(() {
    _selectedDate = null;
    _selectedGroundId = null;
    _selectedGroundName = null;
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AdminNavBar(currentIndex: 4),
      backgroundColor: AppColors.background,
      body: StreamBuilder<ApiQuerySnapshot>(
        stream: _txStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          print("ADMIN ID => ${widget.adminId}");
          print("DOC COUNT => ${snapshot.data?.docs.length}");

          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final docs = snapshot.data?.docs ?? [];

          final allData = docs.map((d) => d.data()).toList()
            ..sort((a, b) {
              final aTime = a['paidAt'] as ApiTimestamp?;
              final bTime = b['paidAt'] as ApiTimestamp?;

              if (aTime == null || bTime == null) return 0;

              return bTime.compareTo(aTime);
            });

          // Aggregates for filtered data
          final totalRevenue = allData.fold<int>(0, (s, d) {
            final a = d['amount'];
            if (a is int) return s + a;
            if (a is double) return s + a.toInt();
            return s + (int.tryParse('$a') ?? 0);
          });

          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              // ── App bar ───────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.card,
                elevation: 0,
                title: const Text(
                  'Revenue',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                actions: [
                  IconButton(
                    icon: Badge(
                      isLabelVisible:
                          _selectedDate != null || _selectedGroundId != null,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.tune_rounded),
                    ),
                    onPressed: () => _showFilterSheet(context),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _RevenueHeader(
                    totalRevenue: totalRevenue,
                    txCount: allData.length,
                    isFiltered:
                        _selectedDate != null || _selectedGroundId != null,
                    filterLabel: _buildFilterLabel(),
                    onClearFilter: _clearFilters,
                    isLoading: isLoading,
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.surface,
                  indicatorWeight: 3,
                  labelColor: AppColors.card,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Transactions'),
                    Tab(text: 'By Ground'),
                  ],
                ),
              ),
            ],
            body: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // ── Tab 1: Transactions ─────────────────────────────
                      allData.isEmpty
                          ? _EmptyState(
                              isFiltered:
                                  _selectedDate != null ||
                                  _selectedGroundId != null,
                              onClear: _clearFilters,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                32,
                              ),
                              itemCount: allData.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) => _TxCard(
                                data: allData[i],
                                onCopyId: (id) {
                                  Clipboard.setData(ClipboardData(text: id));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Payment ID copied'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ),

                      // ── Tab 2: By Ground (uses unfiltered stream) ───────
                      StreamBuilder<ApiQuerySnapshot>(
                        stream: _allTxStream,
                        builder: (context, allSnap) {
                          final allDocs = allSnap.data?.docs ?? [];
                          final allTx = allDocs.map((d) => d.data()).toList();

                          // Build ground stats
                          final Map<String, _GroundStat> gMap = {};
                          for (final d in allTx) {
                            final gId = d['groundId'] as String? ?? '';
                            final gName =
                                d['groundName'] as String? ?? 'Unknown';
                            final amt = d['amount'];
                            final intAmt = amt is int
                                ? amt
                                : amt is double
                                ? amt.toInt()
                                : int.tryParse('$amt') ?? 0;
                            gMap.putIfAbsent(
                              gId,
                              () => _GroundStat(id: gId, name: gName),
                            );
                            gMap[gId]!.total += intAmt;
                            gMap[gId]!.count += 1;
                          }
                          final grounds = gMap.values.toList()
                            ..sort((a, b) => b.total.compareTo(a.total));
                          final grandTotal = grounds.fold<int>(
                            0,
                            (s, g) => s + g.total,
                          );

                          if (grounds.isEmpty) {
                            return _EmptyState(
                              isFiltered: false,
                              onClear: _clearFilters,
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: grounds.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, i) => _GroundCard(
                              stat: grounds[i],
                              rank: i + 1,
                              grandTotal: grandTotal,
                              isSelected: _selectedGroundId == grounds[i].id,
                              onTap: () {
                                setState(() {
                                  if (_selectedGroundId == grounds[i].id) {
                                    _selectedGroundId = null;
                                    _selectedGroundName = null;
                                  } else {
                                    _selectedGroundId = grounds[i].id;
                                    _selectedGroundName = grounds[i].name;
                                  }
                                });
                                _tabController.animateTo(0);
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  String _buildFilterLabel() {
    final parts = <String>[];
    if (_selectedDate != null) {
      parts.add(DateFormat('dd MMM yyyy').format(_selectedDate!));
    }
    if (_selectedGroundName != null) parts.add(_selectedGroundName!);
    return parts.join(' · ');
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StreamBuilder<ApiQuerySnapshot>(
        stream: _allTxStream,
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          final Map<String, String> groundNames = {};
          for (final d in docs) {
            final data = d.data();
            final gId = data['groundId'] as String? ?? '';
            final gName = data['groundName'] as String? ?? '';
            if (gId.isNotEmpty) groundNames[gId] = gName;
          }

          return _FilterSheet(
            selectedDate: _selectedDate,
            selectedGroundId: _selectedGroundId,
            groundNames: groundNames,
            onApply: (date, groundId, groundName) {
              setState(() {
                _selectedDate = date;
                _selectedGroundId = groundId;
                _selectedGroundName = groundName;
              });
              Navigator.pop(context);
            },
            onClear: () {
              _clearFilters();
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Revenue Header — fixed overflow by removing SafeArea & using tight layout
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueHeader extends StatelessWidget {
  final int totalRevenue;
  final int txCount;
  final bool isFiltered;
  final String filterLabel;
  final VoidCallback onClearFilter;
  final bool isLoading;

  const _RevenueHeader({
    required this.totalRevenue,
    required this.txCount,
    required this.isFiltered,
    required this.filterLabel,
    required this.onClearFilter,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, Color(0xFFFF7DB2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),

          // Content — padding-based, no SafeArea to avoid overflow
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter chip
                if (isFiltered)
                  GestureDetector(
                    onTap: onClearFilter,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.filter_alt_rounded,
                            size: 11,
                            color: AppColors.card,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            filterLabel,
                            style: const TextStyle(
                              color: AppColors.card,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.close_rounded,
                            size: 11,
                            color: AppColors.card,
                          ),
                        ],
                      ),
                    ),
                  ),

                Text(
                  isFiltered ? 'Filtered Revenue' : 'Total Revenue',
                  style: TextStyle(
                    color: AppColors.card.withOpacity(0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),

                // Amount
                isLoading
                    ? Container(
                        width: 120,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.card.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹',
                            style: TextStyle(
                              color: AppColors.card.withOpacity(0.8),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _fmt(totalRevenue),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),

                const SizedBox(height: 10),

                // Pills
                Row(
                  children: [
                    _Pill(
                      icon: Icons.receipt_long_rounded,
                      label: '$txCount transactions',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    final s = amount.toString();
    if (s.length <= 3) return s;
    // Indian formatting
    final result = StringBuffer();
    final reversed = s.split('').reversed.toList();
    for (int i = 0; i < reversed.length; i++) {
      if (i == 3 && i < reversed.length)
        result.write(',');
      else if (i > 3 && (i - 3) % 2 == 0 && i < reversed.length) {
        result.write(',');
      }
      result.write(reversed[i]);
    }
    return result.toString().split('').reversed.join();
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Transaction Card
// ─────────────────────────────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final void Function(String) onCopyId;

  const _TxCard({required this.data, required this.onCopyId});

  @override
  Widget build(BuildContext context) {
    final groundName = data['groundName'] as String? ?? 'Ground';
    final slotLabel = data['slotLabel'] as String? ?? '';
    final amount = data['amount'];
    final intAmt = amount is int
        ? amount
        : amount is double
        ? amount.toInt()
        : int.tryParse('$amount') ?? 0;
    final dateStr = data['date'] as String? ?? '';
    final razorId = data['razorpayPaymentId'] as String? ?? '';
    final userPhone = data['userPhone'] as String? ?? '';
    final paidAt = (data['paidAt'] as ApiTimestamp?)?.toDate();
    final payStatus = data['paymentStatus'] as String? ?? 'success';
    final isSuccess = payStatus.toLowerCase() == 'success';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(.08),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.sports_soccer_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        groundName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (slotLabel.isNotEmpty)
                        Text(
                          slotLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹$intAmt',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        payStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isSuccess ? AppColors.primary : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TxRow(
                  icon: Icons.person_outline_rounded,
                  label: 'User',
                  value: userPhone,
                ),
                const SizedBox(height: 6),
                _TxRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: dateStr.isNotEmpty
                      ? () {
                          try {
                            return DateFormat(
                              'EEE, dd MMM yyyy',
                            ).format(DateTime.parse(dateStr));
                          } catch (_) {
                            return dateStr;
                          }
                        }()
                      : 'N/A',
                ),
                if (paidAt != null) ...[
                  const SizedBox(height: 6),
                  _TxRow(
                    icon: Icons.access_time_rounded,
                    label: 'Paid at',
                    value: DateFormat('h:mm a, dd MMM').format(paidAt),
                  ),
                ],
                const SizedBox(height: 6),
                _TxRow(
                  icon: Icons.payment_rounded,
                  label: 'Method',
                  value: (data['paymentMethod'] as String? ?? 'razorpay')
                      .toUpperCase(),
                ),
                if (razorId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => onCopyId(razorId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_rounded,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              razorId,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _TxRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ground Card
// ─────────────────────────────────────────────────────────────────────────────

class _GroundStat {
  final String id;
  final String name;
  int total;
  int count;
  _GroundStat({
    required this.id,
    required this.name,
    this.total = 0,
    this.count = 0,
  });
}

class _GroundCard extends StatelessWidget {
  final _GroundStat stat;
  final int rank;
  final int grandTotal;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroundCard({
    required this.stat,
    required this.rank,
    required this.grandTotal,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    final pct = grandTotal > 0 ? stat.total / grandTotal : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2)
              : isTop
              ? Border.all(
                  color: AppColors.primary.withOpacity(0.5),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Rank
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isTop
                        ? AppColors.primary.withOpacity(0.15)
                        : AppColors.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: isTop
                        ? const Icon(
                            Icons.emoji_events_rounded,
                            size: 16,
                            color: AppColors.primary,
                          )
                        : Text(
                            '$rank',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stat.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isTop)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'TOP',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'FILTERED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${stat.count} booking${stat.count != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${stat.total}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.toDouble(),
                minHeight: 6,
                backgroundColor: const Color(0xFFF0F0F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isTop ? AppColors.primary : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Tap to filter transactions',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(pct * 100).toStringAsFixed(1)}% of total',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Filter Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final DateTime? selectedDate;
  final String? selectedGroundId;
  final Map<String, String> groundNames;
  final void Function(DateTime?, String?, String?) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.selectedDate,
    required this.selectedGroundId,
    required this.groundNames,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? _date;
  String? _groundId;

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDate;
    _groundId = widget.selectedGroundId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onClear,
                child: const Text(
                  'Clear all',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date
          const Text(
            'DATE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: AppColors.card,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: _date != null
                    ? Border.all(color: AppColors.primary)
                    : null,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _date != null
                          ? DateFormat('EEE, dd MMM yyyy').format(_date!)
                          : 'Select date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _date != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_date != null)
                    GestureDetector(
                      onTap: () => setState(() => _date = null),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (widget.groundNames.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'GROUND',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  label: 'All',
                  selected: _groundId == null,
                  onTap: () => setState(() => _groundId = null),
                ),
                ...widget.groundNames.entries.map(
                  (e) => _Chip(
                    label: e.value,
                    selected: _groundId == e.key,
                    onTap: () => setState(() => _groundId = e.key),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final groundName = _groundId != null
                    ? widget.groundNames[_groundId]
                    : null;
                widget.onApply(_date, _groundId, groundName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Apply',
                style: TextStyle(
                  color: AppColors.card,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF5F7F5),
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.card : const Color(0xFF4A5568),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  final VoidCallback onClear;
  const _EmptyState({required this.isFiltered, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No results' : 'No transactions yet',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Try adjusting your filters'
                  : 'Revenue will appear here once bookings are paid',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (isFiltered) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
