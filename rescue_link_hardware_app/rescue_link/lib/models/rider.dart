import 'package:equatable/equatable.dart';

class Rider extends Equatable {
  final String name;
  final String? deviceId;
  final List<String> emergencyContacts;

  const Rider({
    required this.name,
    this.deviceId,
    required this.emergencyContacts,
  });

  Rider copyWith({
    String? name,
    String? deviceId,
    List<String>? emergencyContacts,
  }) {
    return Rider(
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }

  factory Rider.fromJson(Map<String, dynamic> json) {
    return Rider(
      name: json['name'] as String,
      deviceId: json['deviceId'] as String?,
      emergencyContacts: (json['emergencyContacts'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'deviceId': deviceId,
      'emergencyContacts': emergencyContacts,
    };
  }

  @override
  List<Object?> get props => [name, deviceId, emergencyContacts];
}
