import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/roommate_model.dart';

class RoommateService {
  final CollectionReference _collection = 
      FirebaseFirestore.instance.collection('roommate_listings');

  // Add new roommate listing
  Future<void> addRoommateListing(RoommateListing listing) async {
    try {
      await _collection.doc(listing.id).set(listing.toMap());
    } catch (e) {
      throw Exception('Failed to add listing: $e');
    }
  }

  // Get all roommate listings
  Stream<List<RoommateListing>> getAllListings() {
    return _collection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RoommateListing.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  // Get matching listings based on user preferences
  Stream<List<RoommateListing>> getMatchingListings({
    required String gender,
    required String location,
    required String roomType,
    String? excludeUserId,
  }) {
    Query query = _collection.where('gender', isEqualTo: gender);
    
    if (location != 'Any') {
      query = query.where('location', isEqualTo: location);
    }
    if (roomType != 'Any') {
      query = query.where('roomType', isEqualTo: roomType);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RoommateListing.fromMap(doc.data() as Map<String, dynamic>))
          .where((listing) => excludeUserId == null || listing.id != excludeUserId)
          .toList();
    });
  }
}