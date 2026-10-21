import 'package:flutter/material.dart';

import 'services/public_holiday_service.dart';

class PublicHolidaysScreen extends StatefulWidget {
  const PublicHolidaysScreen({super.key});

  @override
  State<PublicHolidaysScreen> createState() => _PublicHolidaysScreenState();
}

class _PublicHolidaysScreenState extends State<PublicHolidaysScreen> {
  final PublicHolidayService _holidayService = PublicHolidayService();

  late Future<List<dynamic>> _holidaysFuture;

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  void _loadHolidays() {
    _holidaysFuture = _holidayService.getPublicHolidays();
  }

  void _refreshHolidays() {
    setState(() {
      _loadHolidays();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('South African Public Holidays'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh holidays',
            onPressed: _refreshHolidays,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _holidaysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 60, color: Colors.grey),
                    const SizedBox(height: 15),
                    const Text(
                      'Unable to load public holidays.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _refreshHolidays,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final holidays = snapshot.data ?? [];

          if (holidays.isEmpty) {
            return const Center(child: Text('No public holidays found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: holidays.length,
            itemBuilder: (context, index) {
              final holiday = holidays[index];

              final name = holiday['localName'] ?? 'Public Holiday';

              final date = holiday['date'] ?? 'Date unavailable';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.calendar_month),
                  ),
                  title: Text(
                    name.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(date.toString()),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
