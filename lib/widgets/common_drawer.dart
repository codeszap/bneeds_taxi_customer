import 'package:bneeds_taxi_customer/screens/ProfileScreen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CommonDrawer extends StatelessWidget {
  final VoidCallback onLogout;

  const CommonDrawer({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            color: Colors.deepPurple,
            child: Column(
              children: [
                SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepPurple.shade50,
                      child: Icon(Icons.person, size: 30, color: Colors.black),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Bneeds",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "bneeds@domain.com",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: "Dashboard",
            onTap: () {
              Navigator.pop(context);
              context.push('/home');
            },
          ),
          // Drawer Menu Items
          _buildDrawerItem(
            icon: Icons.help_outline,
            title: "Help",
            onTap: () {
              Navigator.pop(context);
              context.push('/customer-support');
            },
          ),
          _buildDrawerItem(
            icon: Icons.history,
            title: "My Rides",
            onTap: () {
              Navigator.pop(context);
              context.push('/my-rides');
            },
          ),
          _buildDrawerItem(
            icon: Icons.person_outline,
            title: "Profile",
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
          ),

          _buildDrawerItem(
            icon: Icons.wallet,
            title: "Wallet",
            onTap: () {
              Navigator.pop(context);
              context.push('/wallet');
            },
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onLogout,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
      horizontalTitleGap: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      hoverColor: Colors.deepPurple.withOpacity(0.05),
    );
  }
}
