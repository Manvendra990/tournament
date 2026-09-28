import 'dart:io';
import 'api_client.dart';
import 'session_manager.dart';

Map<String, dynamic> _map(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _list(dynamic value) =>
    (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class AuthApi {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> userLogin(
    String identifier,
    String password,
  ) async {
    final data = _map(
      await _api.post(
        '/auth/user/login',

        auth: false,
        body: {'identifier': identifier, 'password': password},
      ),
    );
    await _save(data);
    return data;
  }

  Future<Map<String, dynamic>> userRegister({
    required String username,
    required String phone,
    required String password,
  }) async {
    final data = _map(
      await _api.post(
        '/auth/user/register',

        auth: false,
        body: {'username': username, 'phone': phone, 'password': password},
      ),
    );
    await _save(data);
    return data;
  }

  Future<Map<String, dynamic>> google(String idToken) async {
    final data = _map(
      await _api.post('/auth/google', auth: false, body: {'idToken': idToken}),
    );
    await _save(data);
    return data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = _map(
      await _api.post(
        '/auth/login',
        auth: false,
        body: {'email': email, 'password': password},
      ),
    );
    await _save(data);
    return data;
  }

  Future<Map<String, dynamic>> requestOtp(String phone) async => _map(
    await _api.post('/auth/otp/request', auth: false, body: {'phone': phone}),
  );

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final data = _map(
      await _api.post(
        '/auth/otp/verify',
        auth: false,
        body: {'phone': phone, 'otp': otp},
      ),
    );
    await _save(data);
    return data;
  }

  Future<Map<String, dynamic>> me() async => _map(await _api.get('/auth/me'));

  Future<void> _save(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    final user = data['user'];
    if (token == null || user is! Map) {
      throw const ApiException('Invalid authentication response');
    }
    await SessionManager.saveSession(
      token: token,
      user: Map<String, dynamic>.from(user),
    );
  }
}

class GroundApi {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> publicList({String? sportType}) async {
    return _list(
      await _api.get(
        '/grounds/public',
        auth: false,
        query: {
          if (sportType != null && sportType.isNotEmpty && sportType != 'All')
            'sportType': sportType,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> getOne(String id) async =>
      _map(await _api.get('/grounds/$id', auth: false));
}

class SlotApi {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> list(
    String groundId,
    DateTime date,
  ) async {
    return _list(
      await _api.get(
        '/slots',
        query: {
          'groundId': groundId,
          'date': date.toIso8601String().split('T').first,
        },
      ),
    );
  }
}

class BookingApi {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> mine() async {
    final rows = _list(await _api.get('/bookings/mine'));
    return rows.map((b) {
      final start = b['startTime']?.toString() ?? '';
      final end = b['endTime']?.toString() ?? '';
      return {
        ...b,
        'slotLabel': start.isNotEmpty && end.isNotEmpty ? '$start - $end' : '',
        'status': b['bookingStatus'],
      };
    }).toList();
  }

  Future<Map<String, dynamic>> create({
    required String slotId,
    String? paymentReference,
    String paymentStatus = 'paid',
    String paymentMethod = 'cash',
  }) async => _map(
    await _api.post(
      '/bookings',
      body: {
        'slotId': slotId,
        'paymentStatus': paymentStatus,
        'paymentMethod': paymentMethod,
        'paymentReference': ?paymentReference,
      },
    ),
  );

  Future<void> cancel(String bookingId, {String? reason}) async {
    await _api.patch(
      '/bookings/$bookingId/cancel',
      body: {'reason': ?reason},
    );
  }
}

class PaymentApi {
  final ApiClient _api = ApiClient.instance;
  Future<List<Map<String, dynamic>>> mine() async {
    final rows = _list(await _api.get('/payments/mine'));
    return rows.map((p) => {...p, 'slotLabel': p['slotLabel'] ?? ''}).toList();
  }
}

class ProfileApi {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> get() async {
    final data = _map(await _api.get('/profile'));
    final user = _map(data['user']);
    await SessionManager.updateUser(user);
    return user;
  }

  Future<Map<String, dynamic>> update({
    String? name,
    String? phone,
    String? bio,
    File? photo,
  }) async {
    final fields = <String, String>{
      'name': ?name,
      'phone': ?phone,
      'bio': ?bio,
    };
    final data = _map(
      await _api.multipartPatch(
        '/profile',
        fields: fields,
        file: photo,
        fileField: 'photo',
      ),
    );
    final user = _map(data['user']);
    await SessionManager.updateUser(user);
    return user;
  }
}

class ApiDocument {
  final String id;
  final Map<String, dynamic> _data;
  ApiDocument(Map<String, dynamic> data)
    : id = data['id']?.toString() ?? data['bookingId']?.toString() ?? '',
      _data = Map<String, dynamic>.from(data);
  Map<String, dynamic> data() => _data;
}

DateTime? apiDate(dynamic value) {
  if (value is DateTime) return value;
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
