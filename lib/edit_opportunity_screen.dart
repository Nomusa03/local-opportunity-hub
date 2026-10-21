import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditOpportunityScreen extends StatefulWidget {
  final String opportunityId;
  final Map<String, dynamic> opportunityData;

  const EditOpportunityScreen({
    super.key,
    required this.opportunityId,
    required this.opportunityData,
  });

  @override
  State<EditOpportunityScreen> createState() => _EditOpportunityScreenState();
}

class _EditOpportunityScreenState extends State<EditOpportunityScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _companyController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late TextEditingController _applicationUrlController;

  late String _selectedCategory;
  late String _selectedField;

  final List<String> _categories = [
    'Jobs',
    'Internships',
    'Learnerships',
    'Bursaries',
  ];

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.opportunityData['title'] ?? '',
    );

    _companyController = TextEditingController(
      text: widget.opportunityData['company'] ?? '',
    );

    _locationController = TextEditingController(
      text: widget.opportunityData['location'] ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.opportunityData['description'] ?? '',
    );
    _applicationUrlController = TextEditingController(
      text: widget.opportunityData['applicationUrl'] ?? '',
    );

    final category = widget.opportunityData['category'];

    _selectedCategory = _categories.contains(category) ? category : 'Jobs';
    final field = widget.opportunityData['field'];

    const availableFields = [
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

    _selectedField = availableFields.contains(field) ? field : 'Other';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _applicationUrlController.dispose();
    super.dispose();
  }

  Future<void> _updateOpportunity() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance
          .collection('opportunities')
          .doc(widget.opportunityId)
          .update({
            'title': _titleController.text.trim(),
            'company': _companyController.text.trim(),
            'location': _locationController.text.trim(),
            'category': _selectedCategory,
            'field': _selectedField,
            'description': _descriptionController.text.trim(),
            'applicationUrl': _applicationUrlController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opportunity updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update opportunity: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Opportunity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Update Opportunity Details',
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

              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Opportunity Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
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
                  // Application URL is optional.
                  if (value == null || value.trim().isEmpty) {
                    return null;
                  }

                  // If a URL is provided, validate it.
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
                onPressed: _updateOpportunity,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
