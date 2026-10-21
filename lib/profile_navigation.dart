import 'package:flutter/material.dart';

class ProfileNavigation {
  static void openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }
}
