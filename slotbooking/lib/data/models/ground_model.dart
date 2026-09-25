class PricingModel {
  final double morning;
  final double afternoon;
  final double evening;
  final double weekend;

  const PricingModel({
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.weekend,
  });

  factory PricingModel.fromMap(Map<String, dynamic> map) => PricingModel(
        morning: (map['morning'] as num?)?.toDouble() ?? 0,
        afternoon: (map['afternoon'] as num?)?.toDouble() ?? 0,
        evening: (map['evening'] as num?)?.toDouble() ?? 0,
        weekend: (map['weekend'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'morning': morning,
        'afternoon': afternoon,
        'evening': evening,
        'weekend': weekend,
      };
}

class GroundModel {
  final String id;
  final String adminId;
  final String name;
  final String sportType;
  final String city;
  final String location;
  final double latitude;
  final double longitude;
  final List<String> images;
  final List<String> amenities;
  final String rules;
  final String status;
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

  factory GroundModel.fromMap(Map<String, dynamic> data) => GroundModel(
        id: data['id']?.toString() ?? '',
        adminId: data['adminId']?.toString() ?? '',
        name: data['name']?.toString() ?? '',
        sportType: data['sportType']?.toString() ?? '',
        city: data['city']?.toString() ?? '',
        location: data['location']?.toString() ?? '',
        latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
        images: List<String>.from(data['images'] ?? const []),
        amenities: List<String>.from(data['amenities'] ?? const []),
        rules: data['rules']?.toString() ?? '',
        status: data['status']?.toString() ?? 'pending',
        pricing: PricingModel.fromMap(
          Map<String, dynamic>.from(data['pricing'] ?? const {}),
        ),
        createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
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
  }) =>
      GroundModel(
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
