import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart' show saveOpportunityToFirestore;

class FirebaseOpportunityDetails extends StatelessWidget {
  final String opportunityId;
  final Map<String, dynamic> opportunity;

  const FirebaseOpportunityDetails({
    super.key,
    required this.opportunityId,
    required this.opportunity,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Opportunity Details')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            // OPPORTUNITY TITLE
            Text(
              opportunity['title'] ?? 'Untitled Opportunity',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // COMPANY
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Company'),
              subtitle: Text(opportunity['company'] ?? 'Not provided'),
            ),

            // LOCATION
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Location'),
              subtitle: Text(opportunity['location'] ?? 'Not provided'),
            ),

            // CATEGORY
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Category'),
              subtitle: Text(opportunity['category'] ?? 'Not provided'),
            ),

            const SizedBox(height: 20),

            // DESCRIPTION HEADING
            const Text(
              'Opportunity Description',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            // DESCRIPTION
            Text(
              opportunity['description'] ?? 'No description available.',
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 30),

            // SAVE OPPORTUNITY BUTTON
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await saveOpportunityToFirestore(
                    opportunityId: opportunityId,
                    title: opportunity['title'] ?? 'Untitled Opportunity',
                    company: opportunity['company'] ?? 'Unknown Company',
                    type: opportunity['category'] ?? 'Jobs',
                  );

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opportunity saved successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save opportunity: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.bookmark_border),
              label: const Text('Save Opportunity'),
            ),

            const SizedBox(height: 16),

            // APPLY NOW BUTTON
            ElevatedButton.icon(
              onPressed: () async {
                final applicationUrl = (opportunity['applicationUrl'] ?? '')
                    .toString()
                    .trim();

                // CHECK IF APPLICATION URL EXISTS

                if (applicationUrl.isEmpty ||
                    applicationUrl == 'https://www.google.com' ||
                    applicationUrl == 'http://www.google.com' ||
                    applicationUrl == 'https://www.google.com/' ||
                    applicationUrl == 'http://www.google.com/') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This is a sample opportunity. No application link is available.',
                      ),
                    ),
                  );
                  return;
                }

                // CHECK IF URL IS VALID
                final uri = Uri.tryParse(applicationUrl);

                if (uri == null ||
                    !['http', 'https'].contains(uri.scheme) ||
                    uri.host.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid application website.'),
                    ),
                  );
                  return;
                }

                // OPEN COMPANY WEBSITE
                try {
                  final success = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!context.mounted) return;

                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open the application website.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to open the application website.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Apply Now'),
            ),
          ],
        ),
      ),
    );
  }
}
