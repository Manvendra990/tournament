import 'package:slotbookingadmin/core/api/api_parsers.dart';

class PricingModel {
  final double morning, afternoon, evening, weekend;
  const PricingModel({
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.weekend,
  });
  factory PricingModel.fromMap(Map<String, dynamic> map) => PricingModel(
    morning: (map['morning'] ?? 0).toDouble(),
    afternoon: (map['afternoon'] ?? 0).toDouble(),
    evening: (map['evening'] ?? 0).toDouble(),
    weekend: (map['weekend'] ?? 0).toDouble(),
  );
  Map<String, dynamic> toMap() => {
    'morning': morning,
    'afternoon': afternoon,
    'evening': evening,
    'weekend': weekend,
  };
}

class GroundModel {
  final String id, adminId, name, sportType, city, location, rules, status;
  final double latitude, longitude;
  final List<String> images, amenities;
  final PricingModel pricing;
  final DateTime createdAt;
  const GroundModel({
    required this.id,
    required this.adminId,
    required this.name,
    required this.sportType,
    required this.city,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.amenities,
    required this.rules,
    required this.status,
    required this.pricing,
    required this.createdAt,
  });
  factory GroundModel.fromMap(Map<String, dynamic> data) {
    final loc = data['location'];
    return GroundModel(
      id: apiId(data),
      adminId: (data['adminId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      sportType: (data['sportType'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      location: loc is String ? loc : (data['address'] ?? '').toString(),
      latitude: ((data['latitude'] ?? (loc is Map ? loc['lat'] : 0)) ?? 0)
          .toDouble(),
      longitude: ((data['longitude'] ?? (loc is Map ? loc['lng'] : 0)) ?? 0)
          .toDouble(),
      images: List<String>.from(data['images'] ?? const []),
      amenities: List<String>.from(data['amenities'] ?? const []),
      rules: (data['rules'] ?? data['description'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      pricing: PricingModel.fromMap(
        Map<String, dynamic>.from(data['pricing'] ?? {}),
      ),
      createdAt: apiDate(data['createdAt']),
    );
  }
  Map<String, dynamic> toMap() => {
    'adminId': adminId,
    'name': name,
    'sportType': sportType,
    'city': city,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'images': images,
    'amenities': amenities,
    'rules': rules,
    'status': status,
    'pricing': pricing.toMap(),
    'createdAt': createdAt.toIso8601String(),
  };
  GroundModel copyWith({
    String? name,
    String? sportType,
    String? city,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? images,
    List<String>? amenities,
    String? rules,
    String? status,
    PricingModel? pricing,
  }) => GroundModel(
    id: id,
    adminId: adminId,
    name: name ?? this.name,
    sportType: sportType ?? this.sportType,
    city: city ?? this.city,
    location: location ?? this.location,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    images: images ?? this.images,
    amenities: amenities ?? this.amenities,
    rules: rules ?? this.rules,
    status: status ?? this.status,
    pricing: pricing ?? this.pricing,
    createdAt: createdAt,
  );
}
