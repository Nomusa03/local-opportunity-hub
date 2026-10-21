import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'edit_opportunity_screen.dart';

class AdminOpportunitiesScreen extends StatelessWidget {
  const AdminOpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Opportunities'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('opportunities')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load opportunities.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final opportunities = snapshot.data?.docs ?? [];

          if (opportunities.isEmpty) {
            return const Center(child: Text('No opportunities published yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: opportunities.length,
            itemBuilder: (context, index) {
              final opportunity = opportunities[index].data();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.work_outline, color: Colors.blue),
                  title: Text(opportunity['title'] ?? 'Untitled Opportunity'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opportunity['company'] ?? 'Unknown Company'),
                      Text('Category: ${opportunity['category'] ?? 'Unknown'}'),
                      Text(
                        'Location: ${opportunity['location'] ?? 'Not provided'}',
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditOpportunityScreen(
                                    opportunityId: opportunities[index].id,
                                    opportunityData: opportunity,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            label: const Text('Edit'),
                          ),

                          const SizedBox(width: 10),

                          TextButton.icon(
                            onPressed: () async {
                              final bool? confirmDelete =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('Delete Opportunity'),
                                      content: const Text(
                                        'Are you sure you want to delete this opportunity? '
                                        'This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(dialogContext, false);
                                          },
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(dialogContext, true);
                                          },
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                              if (confirmDelete != true) return;

                              try {
                                await FirebaseFirestore.instance
                                    .collection('opportunities')
                                    .doc(opportunities[index].id)
                                    .delete();

                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Opportunity deleted successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to delete opportunity: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
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
        },
      ),
    );
  }
}
