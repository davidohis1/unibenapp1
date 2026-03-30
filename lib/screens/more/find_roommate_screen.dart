import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_constants.dart';
import '../../services/roommate_service.dart';
import '../../models/roommate_model.dart';
import 'add_roommate_screen.dart';

class FindRoommateScreen extends StatefulWidget {
  const FindRoommateScreen({Key? key}) : super(key: key);

  @override
  State<FindRoommateScreen> createState() => _FindRoommateScreenState();
}

class _FindRoommateScreenState extends State<FindRoommateScreen> {
  final RoommateService _service = RoommateService();
  String _selectedGenderFilter = 'Any';
  String _selectedLocationFilter = 'Any';
  String _selectedRoomTypeFilter = 'Any';
  
  final List<String> _genders = ['Any', 'Male', 'Female'];
  final List<String> _locations = ['Any', 'EKOSODIN', 'BDPA', 'School Hostel'];
  final List<String> _roomTypes = ['Any', 'Single Room', 'Self Contain', 'Flat'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Roommate', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddRoommateScreen()),
              );
              if (result == true) {
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _buildListingsStream(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Similar Matches',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedGenderFilter,
                  items: _genders,
                  label: 'Gender',
                  onChanged: (value) {
                    setState(() {
                      _selectedGenderFilter = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedLocationFilter,
                  items: _locations,
                  label: 'Location',
                  onChanged: (value) {
                    setState(() {
                      _selectedLocationFilter = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedRoomTypeFilter,
                  items: _roomTypes,
                  label: 'Room Type',
                  onChanged: (value) {
                    setState(() {
                      _selectedRoomTypeFilter = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required String label,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildListingsStream() {
    if (_selectedGenderFilter == 'Any' && 
        _selectedLocationFilter == 'Any' && 
        _selectedRoomTypeFilter == 'Any') {
      // Show all listings
      return StreamBuilder<List<RoommateListing>>(
        stream: _service.getAllListings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final listings = snapshot.data!;
          if (listings.isEmpty) {
            return _buildEmptyState();
          }
          return _buildListings(listings);
        },
      );
    } else {
      // Show filtered matching listings
      return StreamBuilder<List<RoommateListing>>(
        stream: _service.getMatchingListings(
          gender: _selectedGenderFilter == 'Any' ? '' : _selectedGenderFilter,
          location: _selectedLocationFilter == 'Any' ? '' : _selectedLocationFilter,
          roomType: _selectedRoomTypeFilter == 'Any' ? '' : _selectedRoomTypeFilter,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final listings = snapshot.data!;
          if (listings.isEmpty) {
            return _buildEmptyState();
          }
          return _buildListings(listings);
        },
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No roommate listings found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your listing',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListings(List<RoommateListing> listings) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        listing.gender == 'Male' ? Icons.person : 
                        listing.gender == 'Female' ? Icons.person_outline : 
                        Icons.people,
                        color: AppColors.primaryPurple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${listing.gender} • ${listing.roomType}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            listing.location,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  listing.note,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launchWhatsApp(listing.whatsappNumber),
                        icon: const Icon(Icons.chat, size: 18),
                        label: Text(
                          'Chat on WhatsApp',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
      },
    );
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    String formattedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (formattedNumber.startsWith('0')) {
      formattedNumber = '234${formattedNumber.substring(1)}';
    }
    if (!formattedNumber.startsWith('234')) {
      formattedNumber = '234$formattedNumber';
    }
    
    final url = 'https://wa.me/$formattedNumber';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }
}