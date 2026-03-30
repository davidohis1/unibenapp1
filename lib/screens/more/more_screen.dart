import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import 'about_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'my_listing_screen.dart';
import '../voting/voting_screen.dart';
import '../accommodation/accommodation_screen.dart';
import 'discussions_screen.dart';
import 'academia/quiz/quiz_mode_screen.dart';
import 'find_roommate_screen.dart'; // Import the new roommate screen

class MoreScreen extends StatelessWidget {
  const MoreScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<MenuItem> menuItems = [
      MenuItem(
        icon: Icons.forum,
        title: 'Discussions',
        subtitle: 'Join campus discussions',
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DiscussionsScreen()),
        ),
      ),
      MenuItem(
        icon: Icons.how_to_vote,
        title: 'Voting & Polls',
        subtitle: 'Vote on campus issues',
        color: Colors.purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VotingScreen()),
        ),
      ),
      MenuItem(
        icon: Icons.gamepad,
        title: 'Play and Earn',
        subtitle: 'Play quiz games & earn',
        color: Colors.orange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const QuizModeScreen()),
        ),
      ),
      MenuItem(
        icon: Icons.people_alt,
        title: 'Find Roommates',
        subtitle: 'Connect with roommates',
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FindRoommateScreen()),
        ),
      ),
      MenuItem(
        icon: Icons.business,
        title: 'Accommodations',
        subtitle: 'Search for housing',
        color: Colors.green,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AccommodationScreen()),
        ),
      ),
      MenuItem(
        icon: Icons.history,
        title: 'My Listings',
        subtitle: 'Manage your listings',
        color: Colors.red,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyListingsScreen()),
        ),
      ),
      MenuItem(
        icon: Icons.settings,
        title: 'Settings',
        subtitle: 'App preferences',
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        ),
      ),
      MenuItem(
        icon: Icons.help,
        title: 'Help & Support',
        subtitle: 'Get help & support',
        color: Colors.indigo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
        ),
      ),
      MenuItem(
        icon: Icons.info,
        title: 'About',
        subtitle: 'Learn about us',
        color: Colors.cyan,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AboutScreen()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'More',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          return _buildGridItem(context, menuItems[index]);
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, MenuItem item) {
    return Card(
      elevation: 2,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderColor.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.color.withOpacity(0.2),
                      item.color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.black,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: AppColors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}