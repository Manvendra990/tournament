import 'dart:io';

import 'api_client.dart';
import 'session_manager.dart';

class AuthApi {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = Map<String, dynamic>.from(
      await _api.post(
        '/auth/login',
        auth: false,
        body: {'email': email.trim(), 'password': password},
      ),
    );

    final token = data['token']?.toString() ?? '';
    final user = Map<String, dynamic>.from(data['user'] ?? {});

    final role = (data['role'] ?? user['role'] ?? 'user').toString();

    if (token.isNotEmpty) {
      await SessionManager.saveSession(token: token, user: user, role: role);
    }

    return data;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String role = 'admin',
  }) async {
    final data = Map<String, dynamic>.from(
      await _api.post(
        '/auth/register',
        auth: false,
        body: {
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'password': password,
          'role': role,
        },
      ),
    );

    final token = data['token']?.toString();

    final user = Map<String, dynamic>.from(data['user'] ?? {});

    if (token != null && token.isNotEmpty) {
      await SessionManager.saveSession(
        token: token,
        user: user,
        role: (user['role'] ?? role).toString(),
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> me() async {
    final data = Map<String, dynamic>.from(await _api.get('/auth/me'));

    final user = Map<String, dynamic>.from(data['user'] ?? {});

    await SessionManager.updateUser(user);

    return user;
  }

  Future<void> logout() {
    return SessionManager.clear();
  }
}

class GroundApi {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> mine() async {
    return (await _api.get('/grounds') as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> getOne(String id) async {
    return Map<String, dynamic>.from(await _api.get('/grounds/$id'));
  }

  Future<Map<String, dynamic>> create({
    required Map<String, dynamic> data,
    List<File> images = const [],
  }) async {
    final result = await _api.multipart(
      'POST',
      '/grounds',

      // Keep your existing normal-field logic
      fields: {
        for (final e in data.entries)
          if (!['amenities', 'pricing', 'location'].contains(e.key))
            e.key: e.value.toString(),
      },

      // Keep your existing JSON field logic
      jsonFields: {
        'amenities': data['amenities'] ?? [],

        'pricing': data['pricing'] ?? {},

        if (data['location'] != null) 'location': data['location'],
      },

      // Images selected from AddGroundScreen
      files: images,

      // IMPORTANT:
      // Node backend:
      // groundUpload.array("images", 10)
      //
      // Therefore multipart file field MUST be "images".
      fileField: 'images',
    );

    return Map<String, dynamic>.from(result);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _api.patch('/grounds/$id', body: data);
  }

  Future<void> toggle(String id, bool active) async {
    await _api.patch('/grounds/$id/status', body: {'isActive': active});
  }

  Future<List<String>> uploadImages(String id, List<File> images) async {
    final data = Map<String, dynamic>.from(
      await _api.multipart(
        'POST',
        '/grounds/$id/images',

        files: images,

        // IMPORTANT:
        // Node backend also uses:
        // groundUpload.array("images", 10)
        fileField: 'images',
      ),
    );

    return List<String>.from(data['urls'] ?? []);
  }

  Future<void> deleteImage(String id, String imageId) async {
    await _api.delete('/grounds/$id/images/$imageId');
  }

  Future<void> deleteGround(String id) async {
    await _api.delete('/grounds/$id');
  }
}

class SlotApi {
  final ApiClient _api = ApiClient.instance;

  // Specific ground + specific date ke slots
  Future<List<Map<String, dynamic>>> list(
    String groundId,
    DateTime date,
  ) async {
    return (await _api.get(
              '/slots',
              query: {
                'groundId': groundId,
                'date': date.toIso8601String().split('T').first,
              },
            )
            as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // Logged-in admin ke saare slots
  Future<List<Map<String, dynamic>>> mine() async {
    return (await _api.get('/slots/mine') as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // Single slot create
  Future<void> create(Map<String, dynamic> slot) async {
    await _api.post('/slots', body: slot);
  }

  // Multiple slots create
  Future<void> bulk(List<Map<String, dynamic>> slots) async {
    await _api.post('/slots/bulk', body: {'slots': slots});
  }

  // Slot update
  Future<void> update(String id, {String? status, num? price}) async {
    await _api.patch(
      '/slots/$id',
      body: {
        if (status != null) 'status': status,
        if (price != null) 'price': price,
      },
    );
  }

  // Slot delete
  Future<void> delete(String id) async {
    await _api.delete('/slots/$id');
  }
}

class BookingApi {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> admin({
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    return (await _api.get(
              '/bookings/admin',
              query: {
                if (from != null)
                  'from': from.toIso8601String().split('T').first,

                if (to != null) 'to': to.toIso8601String().split('T').first,

                if (status != null) 'status': status,
              },
            )
            as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> mine() async {
    return (await _api.get('/bookings/mine') as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> cancel(String id, {String? reason}) async {
    await _api.patch(
      '/bookings/$id/cancel',
      body: {if (reason != null) 'reason': reason},
    );
  }
}

class DashboardApi {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> stats() async {
    return Map<String, dynamic>.from(await _api.get('/dashboard/stats'));
  }

  Future<List<Map<String, dynamic>>> revenue(String filter) async {
    return (await _api.get('/dashboard/revenue', query: {'filter': filter})
            as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class ProfileApi {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> get() async {
    final d = Map<String, dynamic>.from(await _api.get('/profile'));

    final u = Map<String, dynamic>.from(d['user'] ?? {});

    await SessionManager.updateUser(u);

    return u;
  }

  Future<Map<String, dynamic>> update({
    String? name,
    String? phone,
    String? bio,
    File? photo,
  }) async {
    final d = Map<String, dynamic>.from(
      await _api.multipart(
        'PATCH',
        '/profile',
        fields: {
          if (name != null) 'name': name,

          if (phone != null) 'phone': phone,

          if (bio != null) 'bio': bio,
        },

        files: photo == null ? [] : [photo],

        // Existing profile backend:
        // profileUpload.single("photo")
        fileField: 'photo',
      ),
    );

    final u = Map<String, dynamic>.from(d['user'] ?? {});

    await SessionManager.updateUser(u);

    return u;
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _api.patch(
      '/profile/password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
