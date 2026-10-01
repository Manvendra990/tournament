import 'package:slotbookingadmin/core/api/api_services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:slotbookingadmin/Admin/navbar/adminNavbar.dart';
import 'package:slotbookingadmin/theme/app_colors.dart';
class AddSlotScreen extends StatefulWidget {
  const AddSlotScreen({super.key});
  @override
  State<AddSlotScreen> createState() => _AddSlotScreenState();
}
class _AddSlotScreenState extends State<AddSlotScreen> {
  static const _greenLight = Color(0xFFE8F5EE);
  bool _isLoading = false;
  bool _isSaving = false;
  // Form state
  String? _selectedGroundId;
  String? _selectedSport;
  DateTime _slotDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 7, minute: 0);
  final _amountCtrl = TextEditingController();
  List<Map<String, dynamic>> _grounds = [];
  final _groundApi = GroundApi();
  final _slotApi = SlotApi();
  // Slots created in this session
  final List<_SlotEntry> _createdSlots = [];
  @override
  void initState() {
    super.initState();
    _loadGrounds();
  }
  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }
  // ── Load admin's grounds ───────────────────────────────────────────────────
  Future<void> _loadGrounds() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _groundApi.mine();
      if (!mounted) return;
      final grounds = _normalizeGrounds(rows);
      final previousSelection = _selectedGroundId;
      setState(() {
        _grounds = grounds;
        _selectedGroundId = grounds.any((g) => g['id'] == previousSelection)
            ? previousSelection
            : grounds.isEmpty
            ? null
            : grounds.first['id'] as String;
      });
    } catch (e) {
      if (mounted) _showSnack('Failed to load grounds: $e', Colors.red[700]!);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  List<Map<String, dynamic>> _normalizeGrounds(
    List<Map<String, dynamic>> rows,
  ) => rows
      .map(
        (ground) => {
          'id': (ground['id'] ?? ground['_id'] ?? '').toString(),
          'name': (ground['name'] ?? 'Ground').toString(),
          'sports': _parseSports(ground['sportType'] ?? ground['sport_type']),
        },
      )
      .where((ground) => (ground['id'] as String).isNotEmpty)
      .toList();
  String? get _selectedGroundName {
    for (final ground in _grounds) {
      if (ground['id'] == _selectedGroundId) return ground['name'] as String;
    }
    return null;
  }
  void _selectGround(String id) {
    if (!_grounds.any((ground) => ground['id'] == id)) return;
    setState(() {
      _selectedGroundId = id;
      _selectedSport = null;
    });
  }
  List<String> _parseSports(dynamic value) {
    final values = value is List ? value : (value ?? '').toString().split(',');
    return values.map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty).toSet().toList();
  }

  List<String> get _availableSports {
    for (final ground in _grounds) {
      if (ground['id'] == _selectedGroundId) {
        return List<String>.from(ground['sports'] as List);
      }
    }
    return [];
  }

  Widget _buildSportSelector() {
    final sports = _availableSports;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _fieldLabel('Sport Type'),
      const SizedBox(height: 8),
      if (sports.isEmpty)
        const Text('Is ground mein game add nahi hai. Edit Ground mein games select karein.')
      else
        DropdownButtonFormField<String>(
          key: ValueKey('$_selectedGroundId:$_selectedSport'),
          value: sports.contains(_selectedSport) ? _selectedSport : null,
          isExpanded: true,
          hint: const Text('Select sport'),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: sports.map((sport) => DropdownMenuItem(
            value: sport, child: Text(sport),
          )).toList(),
          onChanged: _isSaving ? null : (value) => setState(() => _selectedSport = value),
        ),
    ]);
  }

  // ── Pick date ──────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _slotDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _slotDate = picked);
  }
  // ── Pick time ──────────────────────────────────────────────────────────────
  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    // if (picked != null) {
    //   setState(() {
    //     if (isStart) {
    //       _startTime = picked;
    //     } else {
    //       _endTime = picked;
    //     }
    //   });
    // }
    if (picked == null) return;
    if (_isTimeInPast(picked)) {
      _showSnack(
        "Selected time has already passed. Please choose a future time",
        Colors.orange[700]!,
      );
      return;
    }
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }
  // check if a time is already in the past or not
  bool _isTimeInPast(TimeOfDay time) {
    final now = DateTime.now();
    final isToday =
        _slotDate.year == now.year &&
        _slotDate.month == now.month &&
        _slotDate.day == now.day;
    if (!isToday) return false;
    final selected = DateTime(
      _slotDate.year,
      _slotDate.month,
      _slotDate.day,
      time.hour,
      time.minute,
    );
    return selected.isBefore(now);
  }
  // ── Validate slot ──────────────────────────────────────────────────────────
  bool _validateSlot() {
    if (_selectedGroundId == null) {
      _showSnack('Please select a ground.', Colors.orange[700]!);
      return false;
    }
    if (!_availableSports.contains(_selectedSport)) {
      _showSnack('Please select a sport for this ground.', Colors.orange[700]!);
      return false;
    }
    final amount = num.tryParse(_amountCtrl.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      _showSnack('Please enter a valid amount greater than zero.', Colors.orange[700]!);
      return false;
    }
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      _showSnack('End time must be after start time.', Colors.orange[700]!);
      return false;
    }
    // prevent saving expired slots for today
    if (_isTimeInPast(_startTime)) {
      _showSnack(
        "Start time has aleady passed for today !",
        Colors.orange[700]!,
      );
      return false;
    }
    return true;
  }
  // ── Build DateTime from date + TimeOfDay ───────────────────────────────────
  DateTime _toDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
  // ── Add slot to session list ───────────────────────────────────────────────
  void _addToList() {
    if (!_validateSlot()) return;
    setState(() {
      _createdSlots.add(
        _SlotEntry(
          groundId: _selectedGroundId!,
          groundName: _selectedGroundName ?? 'Ground',
          sportType: _selectedSport!,
          date: _slotDate,
          startTime: _startTime,
          endTime: _endTime,
          amount: num.parse(_amountCtrl.text.trim()),
        ),
      );
      // Reset time fields for next slot
      _startTime = _endTime;
      _endTime = TimeOfDay(
        hour: (_endTime.hour + 1).clamp(0, 23),
        minute: _endTime.minute,
      );
      _amountCtrl.clear();
    });
  }
  // ── Save all slots through REST API ──────────────────────────────────────
  Future<void> _saveSlots() async {
    if (_createdSlots.isEmpty) {
      _showSnack('Add at least one slot before saving.', Colors.orange[700]!);
      return;
    }
    setState(() => _isSaving = true);
    try {
      final payload = _createdSlots
          .map(
            (slot) => {
              'groundId': slot.groundId,
              'sportType': slot.sportType,
              'date': slot.date.toIso8601String().split('T').first,
              'startTime':
                  '${slot.startTime.hour.toString().padLeft(2, '0')}:'
                  '${slot.startTime.minute.toString().padLeft(2, '0')}:00',
              'endTime':
                  '${slot.endTime.hour.toString().padLeft(2, '0')}:'
                  '${slot.endTime.minute.toString().padLeft(2, '0')}:00',
              'price': slot.amount,
              'amount': slot.amount,
              'status': 'available',
              'bookingStatus': 'available',
            },
          )
          .toList();
      await _slotApi.bulk(payload);
      if (!mounted) return;
      _showSuccessDialog(_createdSlots.length);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save slots: $e', Colors.red[700]!);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  void _showSuccessDialog(int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: _greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '$count Slot${count > 1 ? 's' : ''} Created!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0E1A13),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your slots have been saved and are now available for booking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _createdSlots.clear());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: const Text(
                    'Add More Slots',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/admin/slot');
                },
                child: Text(
                  'View Slots',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F3F0),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
              child: Row(
                children: [
                  // IconButton(
                  //   icon: const Icon(
                  //     Icons.arrow_back_ios_new_rounded,
                  //     color: _green,
                  //   ),
                  //   onPressed: () => context.pop(),
                  // ),
                  Text(
                    '  Manage Slots',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: AppColors.primary,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Create slot card ─────────────────────────────
                          _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Create New Slot',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _buildGroundsSection(),
                                const SizedBox(height: 14),
                                _buildSportSelector(),
                                const SizedBox(height: 14),
                                // Date picker
                                _fieldLabel('Slot Date'),
                                const SizedBox(height: 8),
                                _buildDateTile(),
                                const SizedBox(height: 14),
                                // Time pickers
                                _fieldLabel('Time Range'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTimeTile(
                                        label: 'Start',
                                        time: _startTime,
                                        onTap: () => _pickTime(isStart: true),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.grey[400],
                                        size: 18,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildTimeTile(
                                        label: 'End',
                                        time: _endTime,
                                        onTap: () => _pickTime(isStart: false),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                // Amount
                                _fieldLabel('Amount (₹)'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _amountCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 600',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.currency_rupee_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFB),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Duration preview
                                _buildDurationPreview(),
                                const SizedBox(height: 16),
                                // Add to list button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _addToList,
                                    icon: const Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Add to List',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ── Pending slots list ───────────────────────────
                          if (_createdSlots.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Slots to Save (${_createdSlots.length})',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0E1A13),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _createdSlots.clear()),
                                  child: Text(
                                    'Clear all',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red[400],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ..._createdSlots.asMap().entries.map((e) {
                              final i = e.key;
                              final slot = e.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _SlotListItem(
                                  slot: slot,
                                  index: i,
                                  onDelete: () =>
                                      setState(() => _createdSlots.removeAt(i)),
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            // Save all
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveSlots,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.cloud_upload_rounded,
                                        size: 20,
                                      ),
                                label: Text(
                                  _isSaving
                                      ? 'Saving...'
                                      : 'Save ${_createdSlots.length} Slot${_createdSlots.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  disabledBackgroundColor: AppColors.primary
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),
            // ── Nav bar ──────────────────────────────────────────────────────
            const AdminNavBar(currentIndex: 2),
          ],
        ),
      ),
    );
  }
  Widget _buildGroundsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grounds',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (_grounds.isEmpty)
          Text(
            'No grounds available yet.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _grounds.map((ground) {
              final selected = ground['id'] == _selectedGroundId;
              return ChoiceChip(
                selected: selected,
                onSelected: _isSaving ? null : (_) => _selectGround(ground['id'] as String),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(Icons.check_rounded, size: 16),
                      const SizedBox(width: 4),
                    ],
                    Text(ground['name'] as String),
                  ],
                ),
                selectedColor: AppColors.primary.withValues(alpha: 0.14),
                backgroundColor: const Color(0xFFF8FAFB),
                side: BorderSide(
                  color: selected ? AppColors.primary : Colors.grey[300]!,
                ),
                labelStyle: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
      ],
    );
  }
  Widget _buildDateTile() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Text(
              DateFormat('EEE, dd MMM yyyy').format(_slotDate),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0E1A13),
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
  Widget _buildTimeTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E1A13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildDurationPreview() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    final diffMinutes = endMinutes - startMinutes;
    final isValid = diffMinutes > 0;
    final hours = diffMinutes ~/ 60;
    final mins = diffMinutes % 60;
    final durationText = isValid
        ? (hours > 0 ? '${hours}h ${mins > 0 ? '${mins}m' : ''}' : '${mins}m')
        : 'Invalid time range';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isValid
            ? AppColors.primary.withValues(alpha: 0.2)
            : Colors.red[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.timer_outlined : Icons.error_outline_rounded,
            size: 18,
            color: isValid ? AppColors.primary : Colors.red[400],
          ),
          const SizedBox(width: 10),
          Text(
            isValid ? 'Duration: $durationText' : durationText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isValid ? AppColors.primary : Colors.red[600],
            ),
          ),
          if (isValid && _amountCtrl.text.isNotEmpty) ...[
            const Spacer(),
            Text(
              '₹${_amountCtrl.text}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
// ── Slot list item ────────────────────────────────────────────────────────────
class _SlotListItem extends StatelessWidget {
  final _SlotEntry slot;
  final int index;
  final VoidCallback onDelete;
  const _SlotListItem({
    required this.slot,
    required this.index,
    required this.onDelete,
  });
  static const _green = Color(0xFF0D5C3A);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8F5EE), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5EE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${slot.groundName} • ${slot.sportType}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E1A13),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('dd MMM').format(slot.date)}  •  ${slot.startTime.format(context)} – ${slot.endTime.format(context)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            '₹${slot.amount}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded, size: 18, color: Colors.red[400]),
          ),
        ],
      ),
    );
  }
}
// ── Card wrapper ──────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
// ── Slot entry model ──────────────────────────────────────────────────────────
class _SlotEntry {
  final String groundId;
  final String groundName;
  final String sportType;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final num amount;
  const _SlotEntry({
    required this.groundId,
    required this.groundName,
    required this.sportType,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.amount,
  });
}
