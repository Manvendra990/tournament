import 'package:slotbookingadmin/core/api/api_compat.dart';
import 'package:slotbookingadmin/core/api/api_services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slotbookingadmin/Admin/navbar/adminNavbar.dart';
import 'package:slotbookingadmin/theme/app_colors.dart';
// Display the saved sport of this slot, never the ground's full game list.
String _slotGameType(Map<String, dynamic> data) {
  final value = (data['sportType'] ?? data['sport_type'] ?? '').toString().trim();
  return value.isEmpty ? 'Game not specified' : value;
}
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});
  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}
class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  bool _showUpcoming = true;
  String _filterStatus = 'all';
  final SlotApi _slotApi = SlotApi();
  late Future<List<Map<String, dynamic>>> _slotsFuture;
  @override
  void initState() {
    super.initState();
    _reloadSlots();
  }
  void _reloadSlots() {
    _slotsFuture = _slotApi.mine();
  }
  DateTime? _parseSlotDate(Map<String, dynamic> data) {
    final raw = data['date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
  DateTime? _parseSlotTime(Map<String, dynamic> data, String key) {
    final slotDate = _parseSlotDate(data);
    final raw = data[key]?.toString();
    if (slotDate == null || raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(slotDate.year, slotDate.month, slotDate.day, hour, minute);
  }
  bool _isPastSlot(Map<String, dynamic> data) {
    final now = DateTime.now();
    final slotDate = _parseSlotDate(data);
    final endTime = _parseSlotTime(data, 'endTime');
    if (slotDate == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(slotDate.year, slotDate.month, slotDate.day);
    if (dateOnly.isBefore(today)) return true;
    if (dateOnly.isAfter(today)) return false;
    return endTime != null && now.isAfter(endTime);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERFORMANCE DASHBOARD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'My Slots',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E1A13),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Toggle tabs ───────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _TabChip(
                          label: 'Upcoming',
                          isActive: _showUpcoming,
                          onTap: () => setState(() => _showUpcoming = true),
                        ),
                        _TabChip(
                          label: 'Past History',
                          isActive: !_showUpcoming,
                          onTap: () => setState(() => _showUpcoming = false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FilterRow(
                    selected: _filterStatus,
                    onChanged: (val) => setState(() => _filterStatus = val),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _slotsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Error: ${snapshot.error}',
                              style: TextStyle(color: Colors.red[400]),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(_reloadSlots);
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final allSlots = List<Map<String, dynamic>>.from(
                    snapshot.data ?? [],
                  );
                  final slots = allSlots.where((slot) {
                    final isPast = _isPastSlot(slot);
                    return _showUpcoming ? !isPast : isPast;
                  }).toList();
                  slots.sort((a, b) {
                    final aStart = _parseSlotTime(a, 'startTime');
                    final bStart = _parseSlotTime(b, 'startTime');
                    if (aStart == null || bStart == null) return 0;
                    return _showUpcoming
                        ? aStart.compareTo(bStart)
                        : bStart.compareTo(aStart);
                  });
                  final filteredSlots = _filterStatus == 'all'
                      ? slots
                      : slots.where((slot) {
                          return (slot['status'] ?? '')
                                  .toString()
                                  .toLowerCase() ==
                              _filterStatus;
                        }).toList();
                  final activeCount = filteredSlots.length;
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      setState(_reloadSlots);
                      await _slotsFuture;
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SummaryCard(activeCount: activeCount),
                          const SizedBox(height: 24),
                          if (filteredSlots.isEmpty)
                            _EmptyState(isUpcoming: _showUpcoming)
                          else
                            ...filteredSlots.map((data) {
                              final slotId = data['id']?.toString() ?? '';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _BookingCard(
                                  bookingId: slotId,
                                  data: data,
                                  onEdit: () =>
                                      _showEditDialog(context, slotId, data),
                                  onDetails: () =>
                                      _showDetailsSheet(context, slotId, data),
                                  onDelete: () =>
                                      _deleteSlot(context, slotId, data),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const AdminNavBar(currentIndex: 3),
          ],
        ),
      ),
    );
  }
  // ── Edit slot dialog ───────────────────────────────────────────────────────
  void _showEditDialog(
    BuildContext context,
    String slotId,
    Map<String, dynamic> data,
  ) {
    String status = (data['status'] ?? 'available').toString();
    final priceCtrl = TextEditingController(
      text: (data['price'] ?? 0).toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Update Slot',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: 'available',
                    child: Text('Available'),
                  ),
                  DropdownMenuItem(value: 'blocked', child: Text('Cancelled')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => status = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                final price = num.tryParse(priceCtrl.text.trim());
                if (price == null) {
                  _showSnack(
                    'Please enter a valid price.',
                    Colors.orange[700]!,
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _slotApi.update(slotId, status: status, price: price);
                  if (!mounted) return;
                  setState(_reloadSlots);
                  _showSnack('Slot updated successfully.', AppColors.primary);
                } catch (e) {
                  if (!mounted) return;
                  _showSnack('Error: $e', Colors.red[700]!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).whenComplete(priceCtrl.dispose);
  }
  // ── Details bottom sheet ───────────────────────────────────────────────────
  void _showDetailsSheet(
    BuildContext context,
    String slotId,
    Map<String, dynamic> data,
  ) {
    final slotDate = _parseSlotDate(data);
    final startTime = _parseSlotTime(data, 'startTime');
    final endTime = _parseSlotTime(data, 'endTime');
    final price = data['price'] ?? 0;
    final status = (data['status'] ?? 'available').toString();
    final groundId = data['groundId']?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Slot Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.tag_rounded,
              label: 'Slot ID',
              value: '#${slotId.toUpperCase()}',
            ),
            _DetailRow(
              icon: Icons.sports_rounded,
              label: 'Game Type',
              value: _slotGameType(data),
            ),
            if (groundId.isNotEmpty)
              _DetailRow(
                icon: Icons.sports_rounded,
                label: 'Ground ID',
                value: groundId,
              ),
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date',
              value: slotDate != null
                  ? DateFormat('dd MMM yyyy').format(slotDate)
                  : '-',
            ),
            _DetailRow(
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: (startTime != null && endTime != null)
                  ? '${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}'
                  : '-',
            ),
            _DetailRow(
              icon: Icons.currency_rupee_rounded,
              label: 'Price',
              value: '₹$price',
            ),
            _DetailRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Status',
              value: status.toUpperCase(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ── Delete slot ────────────────────────────────────────────────────────────
  void _deleteSlot(
    BuildContext context,
    String slotId,
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Slot',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: const Text(
          'Are you sure you want to delete this slot? This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _slotApi.delete(slotId);
                if (!mounted) return;
                setState(_reloadSlots);
                _showSnack('Slot deleted successfully.', Colors.red[700]!);
              } catch (e) {
                if (!mounted) return;
                _showSnack('Error: $e', Colors.red[700]!);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Baaki widgets same hain — koi change nahi
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final int activeCount;
  const _SummaryCard({required this.activeCount});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL ACTIVE SLOTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: List.generate(
                  3,
                  (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$activeCount',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            activeCount > 0
                ? 'You have $activeCount slot${activeCount > 1 ? 's' : ''} scheduled.'
                : 'No active slots. Create new slots to get started.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
class _BookingCard extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit, onDetails, onDelete;
  const _BookingCard({
    required this.bookingId,
    required this.data,
    required this.onEdit,
    required this.onDetails,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final dateRaw = data['date']?.toString() ?? '';
    final startRaw = data['startTime']?.toString() ?? '';
    final endRaw = data['endTime']?.toString() ?? '';
    final status = (data['status'] ?? 'available').toString();
    final amount = data['price'] ?? 0;
    final groundId = data['groundId']?.toString() ?? '';
    final slotDate = DateTime.tryParse(dateRaw);
    DateTime? buildTime(String raw) {
      if (slotDate == null || raw.isEmpty) return null;
      final p = raw.split(':');
      if (p.length < 2) return null;
      final hour = int.tryParse(p[0]);
      final minute = int.tryParse(p[1]);
      if (hour == null || minute == null) return null;
      return DateTime(
        slotDate.year,
        slotDate.month,
        slotDate.day,
        hour,
        minute,
      );
    }
    final startTime = buildTime(startRaw);
    final endTime = buildTime(endRaw);
    final timeStr = (startTime != null && endTime != null)
        ? '${DateFormat('hh:mm a').format(startTime)} - ${DateFormat('hh:mm a').format(endTime)}'
        : '--:-- - --:--';
    final dateStr = slotDate != null
        ? DateFormat('dd MMM yyyy').format(slotDate)
        : '--';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isSlotDatePast =
        slotDate != null &&
        DateTime(slotDate.year, slotDate.month, slotDate.day).isBefore(today);
    final isSlotDateToday =
        slotDate != null &&
        DateTime(
          slotDate.year,
          slotDate.month,
          slotDate.day,
        ).isAtSameMomentAs(today);
    final isLive =
        isSlotDateToday &&
        startTime != null &&
        endTime != null &&
        now.isAfter(startTime) &&
        now.isBefore(endTime);
    final isTimeExpiredToday =
        isSlotDateToday && endTime != null && now.isAfter(endTime);
    final isSlotPast = isSlotDatePast || isTimeExpiredToday;
    final displayStatus = isLive
        ? 'live'
        : isSlotPast && status == 'available'
        ? 'expired'
        : status;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusBadge(status: displayStatus),
                const Spacer(),
                Text(
                  '₹$amount',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_rounded, size: 17, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Game: ${_slotGameType(data)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<ApiDocument?>(
              future: groundId.isNotEmpty
                  ? AdminApiCompat.ground(groundId)
                  : Future<ApiDocument?>.value(null),
              builder: (context, snap) {
                final groundName = (snap.data?.data())?['name'] ?? 'Ground';
                final groundCity = (snap.data?.data())?['city'] ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groundName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0E1A13),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            groundCity,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            // ── Action buttons ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isSlotPast ? onDelete : onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: isSlotPast
                            ? Colors.red.shade600
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSlotPast ? Icons.delete_outline : Icons.edit,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSlotPast ? 'Delete' : 'Edit',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onDetails,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
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
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color bg, textColor;
    switch (status.toLowerCase()) {
      case 'live':
        bg = Colors.green.shade50;
        textColor = AppColors.primary;
        break;
      case 'confirmed':
        bg = const Color(0xFFE8F5EE);
        textColor = const Color(0xFF0D5C3A);
        break;
      case 'blocked':
        bg = Colors.red.shade50;
        textColor = Colors.red.shade600;
        break;
      case 'completed':
        bg = const Color(0xFFE8F5EE);
        textColor = const Color(0xFF0D5C3A);
        break;
      case 'expired':
        bg = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        break;
      default:
        bg = const Color(0xFFF0F4FF);
        textColor = const Color(0xFF4A5DA0);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0D5C3A)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0E1A13),
            ),
          ),
        ],
      ),
    );
  }
}
class _TabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _TabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? const Color(0xFF0E1A13) : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }
}
class _FilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _FilterRow({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Filter:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  value: 'all',
                  selected: selected,
                  onTap: onChanged,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Available',
                  value: 'available',
                  selected: selected,
                  onTap: onChanged,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Booked',
                  value: 'booked',
                  selected: selected,
                  onTap: onChanged,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Cancelled',
                  value: 'blocked',
                  selected: selected,
                  onTap: onChanged,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
class _FilterChip extends StatelessWidget {
  final String label, value, selected;
  final ValueChanged<String> onTap;
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final isActive = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
class _EmptyState extends StatelessWidget {
  final bool isUpcoming;
  const _EmptyState({required this.isUpcoming});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              isUpcoming
                  ? Icons.calendar_today_outlined
                  : Icons.history_rounded,
              size: 56,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No upcoming slots' : 'No past slots',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isUpcoming
                  ? 'Create slots from the Slots tab'
                  : 'Your past slots will appear here',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
