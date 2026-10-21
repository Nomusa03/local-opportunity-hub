import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddOpportunityScreen extends StatefulWidget {
  const AddOpportunityScreen({super.key});

  @override
  State<AddOpportunityScreen> createState() => _AddOpportunityScreenState();
}

class _AddOpportunityScreenState extends State<AddOpportunityScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _applicationUrlController = TextEditingController();

  String _selectedCategory = 'Jobs';
  String _selectedField = 'ICT';

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _applicationUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Opportunity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Opportunity Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Opportunity Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter a title'
                    : null,
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company / Organisation',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter a company'
                    : null,
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Opportunity Category',
                  border: OutlineInputBorder(),
                ),
                items: ['Jobs', 'Internships', 'Learnerships', 'Bursaries']
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                initialValue: _selectedField,
                decoration: const InputDecoration(
                  labelText: 'Field of Study',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items:
                    [
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
                    ].map((field) {
                      return DropdownMenuItem<String>(
                        value: field,
                        child: Text(field),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedField = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Opportunity Description',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter a description'
                    : null,
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _applicationUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Application URL',
                  hintText: 'https://example.com/apply',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),

                validator: (value) {
                  // Allow opportunities without an application URL.
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }

                  // Validate the URL only when one is provided.
                  final url = Uri.tryParse(value.trim());

                  if (url == null ||
                      !['http', 'https'].contains(url.scheme) ||
                      url.host.isEmpty) {
                    return 'Please enter a valid website URL';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 25),

              ElevatedButton.icon(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  try {
                    await FirebaseFirestore.instance
                        .collection('opportunities')
                        .add({
                          'title': _titleController.text.trim(),
                          'company': _companyController.text.trim(),
                          'location': _locationController.text.trim(),
                          'category': _selectedCategory,
                          'field': _selectedField,
                          'description': _descriptionController.text.trim(),
                          'applicationUrl': _applicationUrlController.text
                              .trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opportunity published successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    _titleController.clear();
                    _companyController.clear();
                    _locationController.clear();
                    _descriptionController.clear();
                    _applicationUrlController.clear();

                    setState(() {
                      _selectedCategory = 'Jobs';
                      _selectedField = 'ICT';
                    });
                  } catch (e) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to publish opportunity: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Publish Opportunity'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
