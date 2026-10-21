import 'package:flutter/material.dart';

import 'database/database_helper.dart';

class OfflineSavedScreen extends StatelessWidget {
  const OfflineSavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Saved Opportunities')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getSavedOpportunities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load offline opportunities.'),
            );
          }

          final opportunities = snapshot.data ?? [];

          if (opportunities.isEmpty) {
            return const Center(
              child: Text('No offline saved opportunities yet.'),
            );
          }

          return ListView.builder(
            itemCount: opportunities.length,
            itemBuilder: (context, index) {
              final opportunity = opportunities[index];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text(opportunity['title'] ?? 'Opportunity'),
                  subtitle: Text(opportunity['company'] ?? ''),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
