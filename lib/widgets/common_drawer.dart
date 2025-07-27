import 'package:flutter/material.dart';

class CommonDrawer extends StatelessWidget {
  final VoidCallback onLogout;

  const CommonDrawer({super.key, required this.onLogout});

@override
Widget build(BuildContext context) {
  return Drawer(
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: const DrawerHeader(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("saf.dev",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("saf@domain.com",
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ✅ Visible divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: const Divider(
              thickness: 0,
              color: Colors.grey,
            ),
          ),

          buildDrawerItem(
            icon: Icons.help,
            title: "Help",
            onTap: () {
              Navigator.pop(context);
            },
          ),
          buildDrawerItem(
            icon: Icons.history,
            title: "My Rides",
            onTap: () {},
          ),
          buildDrawerItem(
            icon: Icons.person,
            title: "Profile",
            onTap: () {},
          ),

          const Spacer(),

          buildDrawerItem(
            icon: Icons.logout,
            title: "Logout",
            onTap: onLogout,
          ),
        ],
      ),
    ),
  );
}

  Widget buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}
