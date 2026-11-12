import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'database/database_helper.dart';
import 'offline_saved_screen.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'firebase_opportunity_details.dart';
import 'admin_dashboard.dart';
import 'public_holidays_screen.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'notifications_screen.dart';

bool isOpportunitySaved = false;
bool isInternshipSaved = false;
bool isBursarySaved = false;
bool isLearnershipSaved = false;

String userQualification = '';
String userField = '';
String userSpecialisation = '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final messaging = FirebaseMessaging.instance;

  try {
    // Request permission to display browser notifications.
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // Get an FCM token.
    // For Flutter web, provide your Web Push public VAPID key.

    final String? fcmToken = await messaging.getToken();

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (fcmToken != null && currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
            'fcmToken': fcmToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      debugPrint('FCM token saved for signed-in user.');
    } else {
      debugPrint('FCM token not saved: token or signed-in user is missing.');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint('Token refreshed, but no user is signed in.');
        return;
      }

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('Refreshed FCM token saved.');
      } catch (e) {
        debugPrint('Failed to save refreshed FCM token: $e');
      }
    });

    // Handle messages while the app is in the foreground.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        'Foreground notification: '
        '${message.notification?.title}',
      );
      debugPrint('Message body: ${message.notification?.body}');
    });

    // Handle a notification clicked by the user.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification clicked by user');
      debugPrint('Message data: ${message.data}');
    });
  } catch (e, stackTrace) {
    debugPrint('Firebase Messaging error: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(const LocalOpportunityHub());
}

class LocalOpportunityHub extends StatelessWidget {
  const LocalOpportunityHub({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local Opportunity Hub',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const SignUpScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Local Opportunity Hub',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Notifications',

            icon: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('opportunities')
                  .snapshots(),
              builder: (context, opportunitySnapshot) {
                final user = FirebaseAuth.instance.currentUser;
                final field = userField.trim().toLowerCase();

                if (user == null || field.isEmpty) {
                  return const Icon(Icons.notifications_outlined);
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('readNotifications')
                      .snapshots(),
                  builder: (context, readSnapshot) {
                    final opportunities = opportunitySnapshot.data?.docs ?? [];
                    final readDocs = readSnapshot.data?.docs ?? [];

                    final readIds = readDocs
                        .where((doc) => doc.data()['read'] == true)
                        .map((doc) => doc.id)
                        .toSet();

                    final unreadCount = opportunities.where((doc) {
                      final opportunityField = (doc.data()['field'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();

                      return opportunityField == field &&
                          !readIds.contains(doc.id);
                    }).length;

                    return Badge(
                      label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                      isLabelVisible: unreadCount > 0,
                      child: const Icon(Icons.notifications_outlined),
                    );
                  },
                );
              },
            ),

            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      NotificationsScreen(userField: userField),
                ),
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Find Your Next Opportunity',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              const Text(
                'Discover jobs, internships, learnerships and bursaries.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 25),

              Text(
                'Recommended for You',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                userField.isNotEmpty
                    ? 'Based on your $userField profile'
                    : 'Opportunities selected for you',
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),

              const SizedBox(height: 15),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('opportunities')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Unable to load recommendations.');
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final applicantField = userField.trim().toLowerCase();

                  final recommendedOpportunities = snapshot.data!.docs.where((
                    doc,
                  ) {
                    final opportunity = doc.data();

                    final opportunityField = (opportunity['field'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();

                    return applicantField.isNotEmpty &&
                        opportunityField == applicantField;
                  }).toList();

                  if (recommendedOpportunities.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No recommendations available for your field yet.',
                      ),
                    );
                  }

                  return Column(
                    children: recommendedOpportunities.map((doc) {
                      final opportunity = doc.data();

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.school_outlined),
                          title: Text(
                            opportunity['title'] ?? 'Untitled Opportunity',
                          ),
                          subtitle: Text(
                            '${opportunity['company'] ?? 'Unknown Company'}\n'
                            '${opportunity['location'] ?? 'Location not provided'}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FirebaseOpportunityDetails(
                                      opportunityId: doc.id,
                                      opportunity: opportunity,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),

              const Text(
                'Categories',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  CategoryCard(
                    icon: Icons.work,
                    title: 'Jobs',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const JobsScreen(),
                        ),
                      );
                    },
                  ),
                  CategoryCard(
                    icon: Icons.school,
                    title: 'Internships',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InternshipsScreen(),
                        ),
                      );
                    },
                  ),

                  CategoryCard(
                    icon: Icons.menu_book,
                    title: 'Bursaries',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BursariesScreen(),
                        ),
                      );
                    },
                  ),

                  CategoryCard(
                    icon: Icons.computer,
                    title: 'Learnerships',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LearnershipsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PublicHolidaysScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('View South African Public Holidays'),
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                'Latest Opportunities',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('opportunities')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load latest opportunities.'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final opportunities = snapshot.data!.docs;

                  if (opportunities.isEmpty) {
                    return const Text('No new opportunities available yet.');
                  }

                  return Column(
                    children: opportunities.map((doc) {
                      final opportunity = doc.data();

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.work_outline),
                          title: Text(opportunity['title'] ?? 'Untitled'),
                          subtitle: Text(
                            '${opportunity['company'] ?? 'Unknown Company'}\n'
                            '${opportunity['location'] ?? 'Location not provided'}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FirebaseOpportunityDetails(
                                      opportunityId: doc.id,
                                      opportunity: opportunity,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FirestoreSavedScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: Colors.blue),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class OpportunityDetailsScreen extends StatelessWidget {
  const OpportunityDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Opportunity Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Junior Software Developer',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'Pro Stop Recruitment',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),

            const SizedBox(height: 25),

            const Row(
              children: [
                Icon(Icons.location_on_outlined),
                SizedBox(width: 10),
                Expanded(child: Text('Mount Edgecombe, Durban, KwaZulu-Natal')),
              ],
            ),

            const SizedBox(height: 15),

            const Row(
              children: [
                Icon(Icons.work_outline),
                SizedBox(width: 10),
                Text('Full-time Job'),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              'About the Opportunity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'Pro Stop Recruitment is advertising a Junior Software Developer '
              'position based in Mount Edgecombe, Durban. The role involves '
              'software development and working with technologies such as '
              'C#, SQL Server, T-SQL, HTML, CSS and JavaScript.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            const Text(
              'Requirements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),
            const Text(
              '• National Diploma in Information Technology or equivalent qualification\n'
              '• Knowledge of C# and SQL Server\n'
              '• Understanding of T-SQL\n'
              '• Knowledge of HTML, CSS and JavaScript\n'
              '• Familiarity with Git or TFS\n'
              '• Good communication and problem-solving skills',
              style: TextStyle(fontSize: 16, height: 1.8),
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await saveOpportunityToFirestore(
                      opportunityId: 'junior_software_developer',
                      title: 'Junior Software Developer',
                      company: 'Pro Stop Recruitment',
                      type: 'Job',
                    );

                    isOpportunitySaved = true;

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opportunity saved successfully!'),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not save opportunity. Please try again.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bookmark_border),
                label: const Text('Save Opportunity'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This is a sample opportunity. No application link is available.',
                      ),
                    ),
                  );
                },
                child: const Text('Apply Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InternshipsScreen extends StatelessWidget {
  const InternshipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Internships')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('opportunities')
            .where('category', isEqualTo: 'Internships')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load internships.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final internships = snapshot.data!.docs;

          if (internships.isEmpty) {
            return const Center(child: Text('No internships available yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: internships.length,
            itemBuilder: (context, index) {
              final doc = internships[index];
              final opportunity = doc.data();

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: Text(
                    (opportunity['title'] ?? 'Untitled Internship').toString(),
                  ),
                  subtitle: Text(
                    '${opportunity['company'] ?? 'Unknown Company'}\n'
                    '${opportunity['location'] ?? 'Location not provided'}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FirebaseOpportunityDetails(
                          opportunityId: doc.id,
                          opportunity: opportunity,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Jobs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Jobs',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('opportunities')
                    .where('category', isEqualTo: 'Jobs')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Unable to load jobs.'));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final jobs = snapshot.data!.docs;

                  if (jobs.isEmpty) {
                    return const Center(child: Text('No jobs available yet.'));
                  }

                  return ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final doc = jobs[index];
                      final opportunity = doc.data();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.work_outline),
                          title: Text(
                            (opportunity['title'] ?? 'Untitled Job').toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${opportunity['company'] ?? 'Unknown Company'}\n'
                            '${opportunity['location'] ?? 'Location not provided'}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FirebaseOpportunityDetails(
                                      opportunityId: doc.id,
                                      opportunity: opportunity,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BursariesScreen extends StatelessWidget {
  const BursariesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bursaries',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Bursaries',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('opportunities')
                    .where('category', isEqualTo: 'Bursaries')
                    .snapshots(),

                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load bursaries.'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final bursaries = snapshot.data!.docs;

                  if (bursaries.isEmpty) {
                    return const Center(
                      child: Text('No bursaries available yet.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: bursaries.length,

                    itemBuilder: (context, index) {
                      final doc = bursaries[index];
                      final opportunity = doc.data();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),

                        child: ListTile(
                          leading: const Icon(Icons.school_outlined),

                          title: Text(
                            (opportunity['title'] ?? 'Untitled Bursary')
                                .toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),

                          subtitle: Text(
                            '${opportunity['company'] ?? 'Unknown Company'}\n'
                            '${opportunity['location'] ?? 'Location not provided'}',
                          ),

                          isThreeLine: true,

                          trailing: const Icon(Icons.arrow_forward_ios),

                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FirebaseOpportunityDetails(
                                      opportunityId: doc.id,
                                      opportunity: opportunity,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LearnershipsScreen extends StatelessWidget {
  const LearnershipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Learnerships',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Learnerships',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('opportunities')
                    .where('category', isEqualTo: 'Learnerships')
                    .snapshots(),

                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load learnerships.'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final learnerships = snapshot.data!.docs;

                  if (learnerships.isEmpty) {
                    return const Center(
                      child: Text('No learnerships available yet.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: learnerships.length,

                    itemBuilder: (context, index) {
                      final doc = learnerships[index];
                      final opportunity = doc.data();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),

                        child: ListTile(
                          leading: const Icon(Icons.school_outlined),

                          title: Text(
                            (opportunity['title'] ?? 'Untitled Learnership')
                                .toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),

                          subtitle: Text(
                            '${opportunity['company'] ?? 'Unknown Company'}\n'
                            '${opportunity['location'] ?? 'Location not provided'}',
                          ),

                          isThreeLine: true,

                          trailing: const Icon(Icons.arrow_forward_ios),

                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FirebaseOpportunityDetails(
                                      opportunityId: doc.id,
                                      opportunity: opportunity,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> saveOpportunityToFirestore({
  required String opportunityId,
  required String title,
  required String company,
  required String type,
}) async {
  final User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    throw Exception('Please log in to save opportunities.');
  }

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('savedOpportunities')
      .doc(opportunityId)
      .set({
        'title': title,
        'company': company,
        'type': type,
        'savedAt': FieldValue.serverTimestamp(),
      });

  await DatabaseHelper.instance.saveOpportunity(
    id: opportunityId,
    title: title,
    company: company,
    type: type,
  );
}

Stream<QuerySnapshot<Map<String, dynamic>>> getSavedOpportunities() {
  final User? user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return const Stream.empty();
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('savedOpportunities')
      .snapshots();
}

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  Future<void> _removeSavedOpportunity(
    BuildContext context,
    String opportunityId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to manage saved opportunities.'),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedOpportunities')
          .doc(opportunityId)
          .delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opportunity removed from saved.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove opportunity. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Opportunities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: getSavedOpportunities(),
        builder: (context, snapshot) {
          if (FirebaseAuth.instance.currentUser == null) {
            return const Center(
              child: Text('Please log in to view saved opportunities.'),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load saved opportunities.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final savedDocs = snapshot.data?.docs ?? [];

          if (savedDocs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bookmark_border, size: 70),
                    SizedBox(height: 20),
                    Text(
                      'No Saved Opportunities Yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Opportunities you save will appear here.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: savedDocs.length,
            itemBuilder: (context, index) {
              final savedDoc = savedDocs[index];
              final data = savedDoc.data();

              final title = (data['title'] ?? 'Untitled Opportunity')
                  .toString();
              final company = (data['company'] ?? 'Company not provided')
                  .toString();
              final type = (data['type'] ?? 'Opportunity').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(company),
                      const SizedBox(height: 8),

                      Chip(label: Text(type)),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FutureBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>
                                    >(
                                      future: FirebaseFirestore.instance
                                          .collection('opportunities')
                                          .doc(savedDoc.id)
                                          .get(),
                                      builder: (context, opportunitySnapshot) {
                                        if (opportunitySnapshot
                                                .connectionState ==
                                            ConnectionState.waiting) {
                                          return const Scaffold(
                                            body: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        }

                                        if (opportunitySnapshot.hasError ||
                                            !opportunitySnapshot.hasData ||
                                            !opportunitySnapshot.data!.exists) {
                                          return Scaffold(
                                            appBar: AppBar(
                                              title: const Text(
                                                'Opportunity Details',
                                              ),
                                            ),
                                            body: const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(20),
                                                child: Text(
                                                  'This opportunity is no longer available.',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          );
                                        }

                                        return FirebaseOpportunityDetails(
                                          opportunityId: savedDoc.id,
                                          opportunity: opportunitySnapshot.data!
                                              .data()!,
                                        );
                                      },
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View Details'),
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _removeSavedOpportunity(context, savedDoc.id),
                          icon: const Icon(Icons.bookmark_remove_outlined),
                          label: const Text('Remove from Saved'),
                        ),
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

class InternshipDetailsScreen extends StatelessWidget {
  const InternshipDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Internship Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ICT Technician Internship',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'uMngeni-uThukela Water',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            const Row(
              children: [
                Icon(Icons.location_on_outlined),
                SizedBox(width: 8),
                Expanded(child: Text('Pietermaritzburg, KwaZulu-Natal')),
              ],
            ),

            const SizedBox(height: 10),

            const Row(
              children: [
                Icon(Icons.calendar_today_outlined),
                SizedBox(width: 8),
                Expanded(child: Text('Closing: 14 October 2026')),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'About the Opportunity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'uMngeni-uThukela Water is offering an ICT Technician '
              'Internship in Pietermaritzburg. The programme provides '
              'graduates with practical workplace experience in the '
              'Information and Communication Technology environment.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 25),

            const Text(
              'Requirements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              '• Diploma or Degree in Information Technology\n'
              '• Must be an unemployed graduate\n'
              '• Must be willing to gain practical ICT workplace experience\n'
              '• Good communication and interpersonal skills',
              style: TextStyle(fontSize: 16, height: 1.8),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await saveOpportunityToFirestore(
                      opportunityId: 'ict_technician_internship',
                      title: 'ICT Technician Internship',
                      company: 'uMngeni-uThukela Water',
                      type: 'Internship',
                    );

                    isInternshipSaved = true;

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Internship saved successfully!'),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not save internship. Please try again.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bookmark_border),
                label: const Text('Save Opportunity'),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final Uri applicationUrl = Uri.parse(
                    'https://www.umngeni-uthukela.co.za/call-for-applicants-internship-programme-ict-technician/',
                  );

                  final bool opened = await launchUrl(
                    applicationUrl,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open the application website.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Apply Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BursaryDetailsScreen extends StatelessWidget {
  const BursaryDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bursary Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '2027 ISFAP Bursary',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'ISFAP',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            const Row(
              children: [
                Icon(Icons.school_outlined),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Computer Science, Informatics and related fields',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            const Row(
              children: [
                Icon(Icons.location_on_outlined),
                SizedBox(width: 8),
                Expanded(child: Text('South Africa')),
              ],
            ),

            const SizedBox(height: 10),

            const Row(
              children: [
                Icon(Icons.calendar_today_outlined),
                SizedBox(width: 8),
                Expanded(child: Text('Closing: 31 October 2026')),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'About the Bursary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'The ISFAP Bursary provides financial and academic support '
              'to eligible students studying at participating South African '
              'universities. The programme supports selected fields of study, '
              'including technology-related qualifications such as Computer '
              'Science, Informatics and Information Systems.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 25),

            const Text(
              'Eligibility Requirements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              '• South African citizen\n'
              '• Must meet the academic requirements for the selected programme\n'
              '• Must apply to or study at an ISFAP-supported university\n'
              '• Must be applying for an ISFAP-supported field of study\n'
              '• Applicants must meet the financial eligibility requirements',
              style: TextStyle(fontSize: 16, height: 1.8),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await saveOpportunityToFirestore(
                      opportunityId: '2027_isfap_bursary',
                      title: '2027 ISFAP Bursary',
                      company: 'ISFAP',
                      type: 'Bursary',
                    );

                    isBursarySaved = true;

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bursary saved successfully!'),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not save bursary. Please try again.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bookmark_border),
                label: const Text('Save Opportunity'),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final Uri applicationUrl = Uri.parse(
                    'https://applyonline.isfap.org.za/',
                  );

                  final bool opened = await launchUrl(
                    applicationUrl,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open the application website.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Apply Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LearnershipDetailsScreen extends StatelessWidget {
  const LearnershipDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learnership Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'IT Learnership Programme',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Geeks4Learning',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),

            const SizedBox(height: 20),

            const Row(
              children: [
                Icon(Icons.computer_outlined),
                SizedBox(width: 8),
                Expanded(child: Text('Information Technology')),
              ],
            ),

            const SizedBox(height: 10),

            const Row(
              children: [
                Icon(Icons.location_on_outlined),
                SizedBox(width: 8),
                Expanded(child: Text('South Africa')),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'About the Learnership',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'The Geeks4Learning programme provides participants with '
              'training and practical experience to prepare them for careers '
              'in the technology industry. Successful candidates progress '
              'through training and career-path development before entering '
              'an industry-relevant learnership programme.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 25),

            const Text(
              'Requirements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              '• Interest in information technology and digital careers\n'
              '• Willingness to learn and develop new technology skills\n'
              '• Commitment to completing the training programme\n'
              '• Willingness to participate in practical workplace learning',
              style: TextStyle(fontSize: 16, height: 1.8),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await saveOpportunityToFirestore(
                      opportunityId: 'it_learnership_programme',
                      title: 'IT Learnership Programme',
                      company: 'Geeks4Learning',
                      type: 'Learnership',
                    );

                    isLearnershipSaved = true;

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Learnership saved successfully!'),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not save learnership. Please try again.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bookmark_border),
                label: const Text('Save Opportunity'),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final Uri applicationUrl = Uri.parse(
                    'https://geeks4learning.com/applications/',
                  );

                  final bool opened = await launchUrl(
                    applicationUrl,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open the application website.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Apply Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            const Icon(Icons.work_outline, size: 70),

            const SizedBox(height: 15),

            const Text(
              'Join Local Opportunity Hub',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Create an account to discover opportunities that match your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: () async {
                if (passwordController.text.trim() !=
                    confirmPasswordController.text.trim()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Passwords do not match. Please try again.',
                      ),
                    ),
                  );
                  return;
                }
                try {
                  await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text.trim(),
                  );

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CompleteProfileScreen(),
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message ?? 'Failed to create account'),
                    ),
                  );
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Create Account', style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 15),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),

            const Icon(Icons.work_outline, size: 70),

            const SizedBox(height: 15),

            const Text(
              'Welcome Back',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Login to continue finding opportunities for you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 25),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final email = emailController.text.trim();

                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your email address first.'),
                      ),
                    );
                    return;
                  }

                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: email,
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Password reset email sent. Please check your email.',
                        ),
                      ),
                    );
                  } on FirebaseAuthException catch (e) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.message ?? 'Could not send password reset email.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Forgot Password?'),
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: () async {
                try {
                  final credential = await FirebaseAuth.instance
                      .signInWithEmailAndPassword(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );

                  final user = credential.user;
                  if (user == null) return;

                  final profile = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .get();

                  final data = profile.data();
                  final role = data?['role'] ?? 'applicant';

                  userQualification = data?['qualification'] ?? '';
                  userField = data?['field'] ?? '';
                  userSpecialisation = data?['specialisation'] ?? '';

                  if (!context.mounted) return;

                  if (role == 'admin') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminDashboard(
                          onOpenProfile: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.message ?? 'Login failed. Please try again.',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Something went wrong: $e')),
                  );
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Login', style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 15),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SignUpScreen()),
                );
              },
              child: const Text('Don\'t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController townController = TextEditingController();
  final TextEditingController qualificationController = TextEditingController();
  final TextEditingController specialisationController =
      TextEditingController();

  DateTime? selectedDateOfBirth;
  String? selectedField;
  String? selectedProvince;
  bool isSaving = false;

  final List<String> fieldsOfStudy = [
    'ICT',
    'Accounting & Finance',
    'Nursing & Healthcare',
    'Education',
    'Engineering',
    'Business Management',
    'Marketing',
    'Human Resources',
    'Law',
    'Agriculture',
    'Tourism & Hospitality',
    'Public Management',
    'Social Work',
    'Science',
    'Other',
  ];

  final List<String> provinces = [
    'Eastern Cape',
    'Free State',
    'Gauteng',
    'KwaZulu-Natal',
    'Limpopo',
    'Mpumalanga',
    'Northern Cape',
    'North West',
    'Western Cape',
  ];

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Select your date of birth',
    );

    if (picked != null && mounted) {
      setState(() {
        selectedDateOfBirth = picked;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveProfile() async {
    if (isSaving) return;

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      _showMessage('Please enter your first and last names.');
      return;
    }

    if (selectedDateOfBirth == null) {
      _showMessage('Please select your date of birth.');
      return;
    }

    final today = DateTime.now();
    final dob = selectedDateOfBirth!;

    if (dob.isAfter(DateTime(today.year, today.month, today.day))) {
      _showMessage('Date of birth cannot be in the future.');
      return;
    }

    if (selectedField == null) {
      _showMessage('Please select your field of study.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Your session has expired. Please log in again.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final dateString =
          '${dob.year}-'
          '${dob.month.toString().padLeft(2, '0')}-'
          '${dob.day.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'firstName': firstName,
        'lastName': lastName,
        'dateOfBirth': dateString,
        'town': townController.text.trim(),
        'province': selectedProvince,
        'qualification': qualificationController.text.trim(),
        'field': selectedField,
        'specialisation': specialisationController.text.trim(),
        'role': 'applicant',
        'profileCompleted': true,
      }, SetOptions(merge: true));

      userQualification = qualificationController.text.trim();
      userField = selectedField!;
      userSpecialisation = specialisationController.text.trim();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Could not save profile. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    townController.dispose();
    qualificationController.dispose();
    specialisationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.account_circle_outlined, size: 80),
            const SizedBox(height: 15),
            const Text(
              'Tell Us About Yourself',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete your personal and education details '
              'to receive relevant opportunity recommendations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),

            TextField(
              controller: firstNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'First Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: lastNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Last Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 15),

            OutlinedButton.icon(
              onPressed: isSaving ? null : _pickDateOfBirth,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                selectedDateOfBirth == null
                    ? 'Select Date of Birth *'
                    : 'Date of Birth: '
                          '${selectedDateOfBirth!.day.toString().padLeft(2, '0')}/'
                          '${selectedDateOfBirth!.month.toString().padLeft(2, '0')}/'
                          '${selectedDateOfBirth!.year}',
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: townController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Town / City',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: selectedProvince,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Province',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map_outlined),
              ),
              hint: const Text('Select your province'),
              items: provinces.map((province) {
                return DropdownMenuItem<String>(
                  value: province,
                  child: Text(province),
                );
              }).toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      setState(() {
                        selectedProvince = value;
                      });
                    },
            ),
            const SizedBox(height: 25),

            const Text(
              'Education and Career',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: qualificationController,
              decoration: const InputDecoration(
                labelText: 'Qualification Level',
                hintText: 'e.g. Diploma',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: selectedField,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Field of Study *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              hint: const Text('Select your field of study'),
              items: fieldsOfStudy.map((field) {
                return DropdownMenuItem<String>(
                  value: field,
                  child: Text(field),
                );
              }).toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      setState(() {
                        selectedField = value;
                      });
                    },
            ),
            const SizedBox(height: 15),

            TextField(
              controller: specialisationController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Specialisation',
                hintText: 'e.g. Application Development',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer_outlined),
              ),
            ),
            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: isSaving ? null : _saveProfile,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  isSaving ? 'Saving Profile...' : 'Save Profile & Continue',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final imagePath = prefs.getString('profile_image_${user.uid}');

      if (imagePath != null && await File(imagePath).exists()) {
        if (!mounted) return;
        setState(() => _selectedImage = XFile(imagePath));
      }
    } catch (_) {
      // The profile can still be displayed without a picture.
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final extension = p.extension(image.path).toLowerCase();
      final filePath = p.join(directory.path, 'profile_${user.uid}$extension');

      final savedImage = await File(image.path).copy(filePath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_${user.uid}', savedImage.path);

      if (!mounted) return;

      setState(() => _selectedImage = XFile(savedImage.path));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture saved successfully!')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save profile picture.')),
      );
    }
  }

  String _displayValue(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Not provided';
    }
    return value.toString();
  }

  String _formatDateOfBirth(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Not provided';
    }

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _profileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user is logged in.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Could not load profile.'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profile information not found.'));
          }

          final data = snapshot.data!.data() ?? {};
          final isAdmin = data['role'] == 'admin';

          final email = user.email ?? data['email'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickProfileImage,
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _selectedImage != null
                          ? FileImage(File(_selectedImage!.path))
                          : null,
                      child: _selectedImage == null
                          ? const Icon(
                              Icons.account_circle,
                              size: 100,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Center(
                  child: Text(
                    'Tap your picture to change it',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'My Profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                _profileItem(
                  icon: Icons.person_outline,
                  title: 'First Name',
                  value: _displayValue(data['firstName']),
                ),

                _profileItem(
                  icon: Icons.person_outline,
                  title: 'Last Name',
                  value: _displayValue(data['lastName']),
                ),

                _profileItem(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: _displayValue(email),
                ),

                _profileItem(
                  icon: Icons.badge_outlined,
                  title: 'Role',
                  value: isAdmin ? 'Employer' : 'Applicant',
                ),

                if (!isAdmin) ...[
                  const Divider(height: 30),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  _profileItem(
                    icon: Icons.calendar_month,
                    title: 'Date of Birth',
                    value: _formatDateOfBirth(data['dateOfBirth']),
                  ),

                  _profileItem(
                    icon: Icons.location_city,
                    title: 'Town / City',
                    value: _displayValue(data['town']),
                  ),

                  _profileItem(
                    icon: Icons.map_outlined,
                    title: 'Province',
                    value: _displayValue(data['province']),
                  ),

                  const Divider(height: 30),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Education and Career',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  _profileItem(
                    icon: Icons.school_outlined,
                    title: 'Qualification',
                    value: _displayValue(data['qualification']),
                  ),

                  _profileItem(
                    icon: Icons.category_outlined,
                    title: 'Field of Study',
                    value: _displayValue(data['field']),
                  ),

                  _profileItem(
                    icon: Icons.code,
                    title: 'Specialisation',
                    value: _displayValue(data['specialisation']),
                  ),
                ],

                const SizedBox(height: 25),

                if (isAdmin) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminDashboard(
                            onOpenProfile: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProfileScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Employer Hub',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],

                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );

                    if (!context.mounted) return;

                    // Rebuild the profile to display the latest details.
                    setState(() {});
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Edit Profile', style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 15),

                OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();

                    userQualification = '';
                    userField = '';
                    userSpecialisation = '';

                    if (!context.mounted) return;

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Logout'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController townController = TextEditingController();
  final TextEditingController qualificationController = TextEditingController();
  final TextEditingController fieldController = TextEditingController();
  final TextEditingController specialisationController =
      TextEditingController();

  DateTime? selectedDateOfBirth;
  String? selectedProvince;

  bool isLoading = true;
  bool isSaving = false;
  bool isAdmin = false;

  final List<String> provinces = [
    'Eastern Cape',
    'Free State',
    'Gauteng',
    'KwaZulu-Natal',
    'Limpopo',
    'Mpumalanga',
    'Northern Cape',
    'North West',
    'Western Cape',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data() ?? {};

      emailController.text = user.email ?? data['email'] ?? '';
      firstNameController.text = data['firstName'] ?? '';
      lastNameController.text = data['lastName'] ?? '';
      townController.text = data['town'] ?? '';
      qualificationController.text = data['qualification'] ?? '';
      fieldController.text = data['field'] ?? '';
      specialisationController.text = data['specialisation'] ?? '';

      final dob = data['dateOfBirth'];
      DateTime? parsedDob;
      if (dob is String) {
        parsedDob = DateTime.tryParse(dob);
      }

      final province = data['province'];

      if (!mounted) return;

      setState(() {
        isAdmin = data['role'] == 'admin';
        selectedDateOfBirth = parsedDob;
        selectedProvince = province is String && provinces.contains(province)
            ? province
            : null;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load profile details.')),
      );
    }
  }

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate:
          selectedDateOfBirth ??
          DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Select your date of birth',
    );

    if (picked != null && mounted) {
      setState(() => selectedDateOfBirth = picked);
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || isSaving) return;

    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your first and last names.'),
        ),
      );
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    if (!isAdmin && selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth.')),
      );
      return;
    }

    if (!isAdmin && selectedDateOfBirth!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of birth cannot be in the future.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final updates = <String, dynamic>{
        'firstName': firstName,
        'lastName': lastName,
      };

      if (!isAdmin) {
        updates['dateOfBirth'] =
            '${selectedDateOfBirth!.year}-'
            '${selectedDateOfBirth!.month.toString().padLeft(2, '0')}-'
            '${selectedDateOfBirth!.day.toString().padLeft(2, '0')}';
        updates['town'] = townController.text.trim();
        updates['province'] = selectedProvince;
        updates['qualification'] = qualificationController.text.trim();
        updates['field'] = fieldController.text.trim();
        updates['specialisation'] = specialisationController.text.trim();

        userQualification = qualificationController.text.trim();
        userField = fieldController.text.trim();
        userSpecialisation = specialisationController.text.trim();
      }

      final emailChanged = email != (user.email ?? '');

      // Only save the current email to Firestore until a new login
      // email has been verified through Firebase Authentication.
      if (!isAdmin || !emailChanged) {
        updates['email'] = user.email ?? email;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updates, SetOptions(merge: true));

      if (isAdmin && emailChanged) {
        await user.verifyBeforeUpdateEmail(email);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAdmin && emailChanged
                ? 'Check your email to verify the new login address.'
                : 'Profile updated successfully!',
          ),
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Could not update the email address.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    townController.dispose();
    qualificationController.dispose();
    fieldController.dispose();
    specialisationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.edit_note, size: 80),
            const SizedBox(height: 25),

            TextField(
              controller: firstNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'First Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: lastNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Last Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              readOnly: !isAdmin,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            if (!isAdmin) ...[
              const SizedBox(height: 15),

              OutlinedButton.icon(
                onPressed: _pickDateOfBirth,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  selectedDateOfBirth == null
                      ? 'Select Date of Birth *'
                      : 'Date of Birth: '
                            '${selectedDateOfBirth!.day.toString().padLeft(2, '0')}/'
                            '${selectedDateOfBirth!.month.toString().padLeft(2, '0')}/'
                            '${selectedDateOfBirth!.year}',
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: townController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Town / City',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                initialValue: selectedProvince,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                hint: const Text('Select your province'),
                items: provinces.map((province) {
                  return DropdownMenuItem<String>(
                    value: province,
                    child: Text(province),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedProvince = value);
                },
              ),
              const SizedBox(height: 25),

              const Text(
                'Education and Career',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: qualificationController,
                decoration: const InputDecoration(
                  labelText: 'Qualification',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: fieldController,
                decoration: const InputDecoration(
                  labelText: 'Field of Study',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: specialisationController,
                decoration: const InputDecoration(
                  labelText: 'Specialisation',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.code),
                ),
              ),
            ],

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: isSaving ? null : _saveProfile,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(isSaving ? 'Saving...' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String selectedCategory = 'All';
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Opportunities')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Search opportunities',
                hintText: 'e.g. Software Developer',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    [
                      'All',
                      'Jobs',
                      'Internships',
                      'Learnerships',
                      'Bursaries',
                    ].map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: selectedCategory == category,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedCategory = category;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('opportunities')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Unable to load opportunities.'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final searchText = searchController.text.trim().toLowerCase();

                  final filteredDocs = snapshot.data!.docs.where((doc) {
                    final opportunity = doc.data();

                    final title = (opportunity['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    final company = (opportunity['company'] ?? '')
                        .toString()
                        .toLowerCase();
                    final location = (opportunity['location'] ?? '')
                        .toString()
                        .toLowerCase();
                    final category = (opportunity['category'] ?? '')
                        .toString()
                        .toLowerCase();
                    final field = (opportunity['field'] ?? '')
                        .toString()
                        .toLowerCase();

                    final matchesSearch =
                        searchText.isEmpty ||
                        title.contains(searchText) ||
                        company.contains(searchText) ||
                        location.contains(searchText) ||
                        category.contains(searchText) ||
                        field.contains(searchText);

                    final matchesCategory =
                        selectedCategory == 'All' ||
                        category == selectedCategory.toLowerCase();

                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text('No opportunities found.'));
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final opportunity = doc.data();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.work_outline),

                          title: Text(
                            (opportunity['title'] ?? 'Untitled Opportunity')
                                .toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),

                          subtitle: Text(
                            '${opportunity['company'] ?? 'Unknown Company'}'
                            ' • ${opportunity['location'] ?? 'Unknown Location'}'
                            '\n${opportunity['category'] ?? ''}'
                            ' • ${opportunity['field'] ?? ''}',
                          ),

                          isThreeLine: true,

                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FirebaseOpportunityDetails(
                                      opportunityId: doc.id,
                                      opportunity: opportunity,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FirestoreSavedScreen extends StatelessWidget {
  const FirestoreSavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Opportunities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.offline_pin),
            tooltip: 'Offline Saved Opportunities',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OfflineSavedScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: getSavedOpportunities(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load saved opportunities.'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final savedDocs = snapshot.data!.docs;

          if (savedDocs.isEmpty) {
            return const Center(child: Text('No Saved Opportunities Yet'));
          }

          return ListView.builder(
            itemCount: savedDocs.length,
            itemBuilder: (context, index) {
              final data = savedDocs[index].data();

              return Card(
                child: ListTile(
                  title: Text(data['title'] ?? 'Opportunity'),
                  subtitle: Text(data['company'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.bookmark_remove_outlined,
                      color: Colors.red,
                    ),
                    tooltip: 'Remove from Saved',
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;

                      if (user == null) return;

                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('savedOpportunities')
                            .doc(savedDocs[index].id)
                            .delete();
                        await DatabaseHelper.instance.deleteSavedOpportunity(
                          savedDocs[index].id,
                        );

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opportunity removed from saved.'),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not remove opportunity.'),
                          ),
                        );
                      }
                    },
                  ),
                  onTap: () async {
                    final opportunityId = savedDocs[index].id;

                    try {
                      final opportunityDoc = await FirebaseFirestore.instance
                          .collection('opportunities')
                          .doc(opportunityId)
                          .get();

                      if (!context.mounted) return;

                      if (opportunityDoc.exists) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FirebaseOpportunityDetails(
                              opportunityId: opportunityId,
                              opportunity: opportunityDoc.data()!,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Opportunity details are not available.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open opportunity details.'),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
