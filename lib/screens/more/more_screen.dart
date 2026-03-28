import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_constants.dart';
import 'about_screen.dart';
import 'help_screen.dart';
import 'settings_screen.dart';
import 'my_listing_screen.dart';
import 'ai_study_assistant_screen.dart';
import '../voting/voting_screen.dart'; 
import '../accommodation/accommodation_screen.dart';
import 'discussions_screen.dart';
import 'academia/quiz_game_lobby_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('More', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuItem(
            context,
            Icons.school,  // Academia icon
            'Voting & Polls',
            ' Vote on campus issues and events',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VotingScreen(),
              ),
            ),
          ),
          _buildMenuItem(
            context,
            Icons.people_alt,
            'Find Roommates',
            'Connect with potential roommates',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Find Roommates feature coming soon!')),
              );
            },
          ),
          _buildMenuItem(
            context,
            Icons.smart_toy, // Or Icons.robot, Icons.auto_awesome
            'Find Accommodations',
            'Search for available accommodations',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AccommodationScreen(),
              ),
            ),
          ),
          _buildMenuItem(
            context,
            Icons.forum,
            'Discussions',
            'Join campus discussions',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DiscussionsScreen(),
              ),
            ),
          ),
          _buildMenuItem(
            context,
            Icons.forum,
            'Play and earn',
            'Play quiz games and earn rewards',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const QuizGameLobbyScreen(),
              ),
            ),
          ),
          _buildMenuItem(
            context,
            Icons.bookmark,
            'Saved Items',
            'View your saved posts and products',
            () {},
          ),
          _buildMenuItem(
            context,
            Icons.history,
            'My Listings',
            'Manage your products and services',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyListingsScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            Icons.settings,
            'Settings',
            'App preferences and account settings',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),

          _buildMenuItem(
            context,
            Icons.help,
            'Help & Support',
            'Get help and contact support',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
            ),
          ),

          _buildMenuItem(
            context,
            Icons.info,
            'About',
            'Learn more about Campus Connect',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightPurple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryPurple, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.grey,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}