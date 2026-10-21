import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_opportunity_details.dart';

import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  final String userField;

  const NotificationsScreen({super.key, required this.userField});

  @override
  Widget build(BuildContext context) {
    final applicantField = userField.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: applicantField.isEmpty
          ? const Center(
              child: Text(
                'Your field is not set. Please update your profile.',
                textAlign: TextAlign.center,
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('opportunities')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load notifications.'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final opportunities =
                    snapshot.data?.docs.where((doc) {
                      final data = doc.data();
                      final field = (data['field'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();

                      return field == applicantField;
                    }).toList() ??
                    [];

                if (opportunities.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching opportunities yet. Check again later!',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: opportunities.length,
                  itemBuilder: (context, index) {
                    final opportunityDoc = opportunities[index];
                    final data = opportunityDoc.data();
                    final createdAt = data['createdAt'] as Timestamp?;

                    final userId = FirebaseAuth.instance.currentUser!.uid;

                    final readStatusRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('readNotifications')
                        .doc(opportunityDoc.id);

                    final isNew =
                        createdAt != null &&
                        DateTime.now().difference(createdAt.toDate()).inDays <
                            7;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        onTap: () async {
                          try {
                            await readStatusRef.set({
                              'read': true,
                              'readAt': FieldValue.serverTimestamp(),
                            });
                          } catch (error) {
                            debugPrint(
                              'Could not mark notification as read: $error',
                            );
                          }

                          if (!context.mounted) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FirebaseOpportunityDetails(
                                opportunityId: opportunityDoc.id,
                                opportunity: data,
                              ),
                            ),
                          );
                        },

                        leading:
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: readStatusRef.snapshots(),
                              builder: (context, readSnapshot) {
                                final isRead =
                                    readSnapshot.data?.data()?['read'] == true;

                                return Icon(
                                  isRead
                                      ? Icons.notifications_none
                                      : Icons.notifications_active,
                                  color: isRead ? Colors.grey : Colors.blue,
                                );
                              },
                            ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                data['title']?.toString() ?? 'New opportunity',
                              ),
                            ),
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: readStatusRef.snapshots(),
                              builder: (context, readSnapshot) {
                                final isRead =
                                    readSnapshot.data?.data()?['read'] == true;

                                if (isNew && !isRead) {
                                  return const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  );
                                }

                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${data['company'] ?? 'Company not specified'}'
                          '\n${data['category'] ?? 'Opportunity'}'
                          ' • ${data['location'] ?? 'Location not specified'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
