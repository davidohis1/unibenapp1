class RoommateListing {
  final String id;
  final String name;
  final String location;
  final String gender;
  final String roomType;
  final String note;
  final String whatsappNumber;
  final DateTime timestamp;

  RoommateListing({
    required this.id,
    required this.name,
    required this.location,
    required this.gender,
    required this.roomType,
    required this.note,
    required this.whatsappNumber,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'gender': gender,
      'roomType': roomType,
      'note': note,
      'whatsappNumber': whatsappNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RoommateListing.fromMap(Map<String, dynamic> map) {
    return RoommateListing(
      id: map['id'],
      name: map['name'],
      location: map['location'],
      gender: map['gender'],
      roomType: map['roomType'],
      note: map['note'],
      whatsappNumber: map['whatsappNumber'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}