import 'package:flutter/material.dart';

import 'add_opportunity_screen.dart';
import 'admin_opportunities_screen.dart';

class AdminDashboard extends StatelessWidget {
  final VoidCallback? onOpenProfile;

  const AdminDashboard({super.key, this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            const Text(
              'Manage Opportunities',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'Create and manage opportunities for applicants.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: onOpenProfile == null ? null : () => onOpenProfile!(),
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('My Profile'),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddOpportunityScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add New Opportunity'),
            ),

            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminOpportunitiesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('View All Opportunities'),
            ),
          ],
        ),
      ),
    );
  }
}
