import 'package:slotbooking/core/api/api_services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

// CHANGE THIS PATH if your RazorpayService file is stored elsewhere.
import 'package:slotbooking/User/payments/razorpay_service.dart';

class BookingPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingPaymentScreen({super.key, required this.bookingData});

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  bool _isProcessing = false;

  late RazorpayService _razorpayService;

  // ───────────────────────────────────────────────────────────────────────────
  // INIT
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _razorpayService = RazorpayService(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onExternalWallet: _handleExternalWallet,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ───────────────────────────────────────────────────────────────────────────

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'N/A';

    return DateFormat('EEE, MMM d, yyyy').format(value);
  }

  String _formatTime(DateTime? value) {
    if (value == null) return 'N/A';

    return DateFormat('h:mm a').format(value);
  }

  String _formatDuration() {
    if (widget.bookingData['durationLabel'] is String) {
      return widget.bookingData['durationLabel'] as String;
    }

    final durationMap = widget.bookingData['timeDuretion'];

    if (durationMap is Map) {
      final hours = durationMap['hour'] is num
          ? (durationMap['hour'] as num).toInt()
          : 0;

      final minutes = durationMap['minute'] is num
          ? (durationMap['minute'] as num).toInt()
          : 0;

      if (hours > 0 && minutes > 0) {
        return '${hours}h ${minutes}m';
      }

      if (hours > 0) {
        return '${hours}h';
      }

      if (minutes > 0) {
        return '${minutes}m';
      }
    }

    return '1 Hour';
  }

  int get _amount {
    final raw = widget.bookingData['amount'];

    if (raw is int) return raw;

    if (raw is double) {
      return raw.toInt();
    }

    return int.tryParse('$raw') ?? 0;
  }

  DateTime? get _startTime => _toDateTime(widget.bookingData['startTime']);

  DateTime? get _endTime => _toDateTime(widget.bookingData['endTime']);

  String get _userId => widget.bookingData['userId'] as String? ?? '';

  String get _userPhone => widget.bookingData['userPhone'] as String? ?? '';

  String get _adminId => widget.bookingData['adminId'] as String? ?? '';

  String get _groundId => widget.bookingData['groundId'] as String? ?? '';

  String get _groundName =>
      widget.bookingData['groundName'] as String? ?? 'Ground';

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // RAZORPAY
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _confirmBooking() async {
    if (_isProcessing) return;

    if (_amount <= 0) {
      _showSnack('Invalid payment amount');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    final options = <String, dynamic>{
      // ---------------------------------------------------------
      // IMPORTANT:
      // Put Razorpay TEST KEY ID here.
      //
      // Example:
      // rz*************
      //
      // NEVER put Razorpay KEY SECRET in Flutter.
      // ---------------------------------------------------------

      'key': 'rzp_test_TcKBPhHFKQLo8p',

      // Razorpay amount is in paise.
      // ₹100 = 10000 paise.
      'amount': _amount * 100,

      'currency': 'INR',

      'name': 'Kinetic',

      'description': 'Ground Booking - $_groundName',

      'prefill': {'contact': _userPhone},

      'theme': {'color': '#D32F2F'},
    };

    try {
      await _razorpayService.openCheckout(options: options);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      _showSnack('Unable to open payment gateway: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PAYMENT SUCCESS
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final paymentId = response.paymentId ?? '';

      if (paymentId.isEmpty) {
        throw Exception('Razorpay payment ID missing');
      }

      await _saveBooking(paymentReference: paymentId);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Booking Confirmed 🎉'),
            content: const Text(
              'Payment successful.\n'
              'Your slot has been confirmed.\n'
              'You can view it in your bookings.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      context.go('/user/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      _showSnack('Payment succeeded but booking could not be saved: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PAYMENT ERROR / CANCEL
  // ───────────────────────────────────────────────────────────────────────────

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }

    final message = response.message ?? 'Payment failed or cancelled';

    _showSnack(message);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // EXTERNAL WALLET
  // ───────────────────────────────────────────────────────────────────────────

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showSnack(
      'External wallet selected: '
      '${response.walletName ?? ''}',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SAVE BOOKING
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _saveBooking({required String paymentReference}) async {
    final slotId = widget.bookingData['slotId']?.toString() ?? '';

    if (slotId.isEmpty) {
      throw Exception('Slot ID is missing');
    }

    await BookingApi().create(
      slotId: slotId,

      paymentStatus: 'paid',

      paymentMethod: 'razorpay',

      paymentReference: paymentReference,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final slotLabel = widget.bookingData['slotLabel'] as String? ?? 'Slot';

    final bookingStatus =
        widget.bookingData['bookingStatus'] as String? ?? 'available';

    final timeLabel =
        '${_formatTime(_startTime)} - '
        '${_formatTime(_endTime)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),

        title: const Text(
          'Confirm Booking',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const SizedBox(height: 4),

                    const Text(
                      'Review your selection',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Please confirm the details below before proceeding to pay.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ─────────────────────────────────────
                    // DETAILS CARD
                    // ─────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),

                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,

                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEB),
                                    borderRadius: BorderRadius.circular(20),
                                  ),

                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFFD32F2F),
                                    size: 20,
                                  ),
                                ),

                                const SizedBox(width: 14),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,

                                    children: [
                                      Text(
                                        'GROUND',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade500,
                                          letterSpacing: 1.2,
                                        ),
                                      ),

                                      const SizedBox(height: 2),

                                      Text(
                                        _groundName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Divider(height: 1, color: Colors.grey.shade100),

                          Padding(
                            padding: const EdgeInsets.all(16),

                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _GridCell(
                                        icon: Icons.calendar_today_rounded,
                                        iconColor: const Color(0xFFD32F2F),
                                        iconBg: const Color(0xFFFFEBEB),
                                        label: 'DATE',
                                        value: _formatDate(_startTime),
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: _GridCell(
                                        icon: Icons.access_time_rounded,
                                        iconColor: const Color(0xFFD32F2F),
                                        iconBg: const Color(0xFFFFEBEB),
                                        label: 'TIME',
                                        value: timeLabel,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _GridCell(
                                        icon: Icons.bolt_rounded,
                                        iconColor: const Color(0xFFD32F2F),
                                        iconBg: const Color(0xFFFFEBEB),
                                        label: 'DURATION',
                                        value: _formatDuration(),
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: _GridCell(
                                        icon:
                                            Icons.check_circle_outline_rounded,
                                        iconColor: const Color(0xFF2E7D32),
                                        iconBg: const Color(0xFFE8F5E9),
                                        label: 'BOOKING STATUS',
                                        value: bookingStatus.toUpperCase(),
                                        valueColor: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ─────────────────────────────────────
                    // PAYMENT SUMMARY
                    // ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              Text(
                                'Booking Fee',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),

                              Text(
                                '₹${_amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),

                            child: Row(
                              children: List.generate(
                                40,
                                (i) => Expanded(
                                  child: Container(
                                    height: 1,
                                    color: i % 2 == 0
                                        ? Colors.grey.shade300
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,

                            children: [
                              const Text(
                                'Total Amount',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),

                              Text(
                                '₹$_amount',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─────────────────────────────────────────────
            // BOTTOM PAYMENT BAR
            // ─────────────────────────────────────────────
            Container(
              color: Colors.white,

              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),

                      const SizedBox(width: 6),

                      Text(
                        'Secure Payment via Razorpay',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 52,

                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmBooking,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),

                        disabledBackgroundColor: const Color(
                          0xFFD32F2F,
                        ).withOpacity(0.6),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),

                        elevation: 0,
                      ),

                      child: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Pay Now  •  ₹$_amount',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DISPOSE
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID CELL
// ─────────────────────────────────────────────────────────────────────────────

class _GridCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final Color? valueColor;

  const _GridCell({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Container(
          width: 32,
          height: 32,

          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),

          child: Icon(icon, size: 16, color: iconColor),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 1.1,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
