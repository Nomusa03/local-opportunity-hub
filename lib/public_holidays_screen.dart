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

  DateTime _selectedDate = DateTime.now();

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

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Map<String, dynamic>? _holidayForDate(List<dynamic> holidays, DateTime date) {
    for (final holiday in holidays) {
      final holidayDateString = holiday['date'];

      if (holidayDateString == null) {
        continue;
      }

      final holidayDate = DateTime.tryParse(holidayDateString.toString());

      if (holidayDate != null && _isSameDate(holidayDate, date)) {
        return Map<String, dynamic>.from(holiday);
      }
    }

    return null;
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

          final selectedHoliday = _holidayForDate(holidays, _selectedDate);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Calendar
                CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  onDateChanged: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                ),

                const Divider(),

                // Selected date information
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: selectedHoliday != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.celebration),
                                    SizedBox(width: 10),
                                    Text(
                                      'Public Holiday',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  selectedHoliday['localName']?.toString() ??
                                      'Public Holiday',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  selectedHoliday['date']?.toString() ??
                                      'Date unavailable',
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                const Icon(Icons.event_available, size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  '${_selectedDate.day}/'
                                  '${_selectedDate.month}/'
                                  '${_selectedDate.year}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'No public holiday on this date.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                // List of all holidays
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'All Public Holidays',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        onTap: () {
                          final parsedDate = DateTime.tryParse(date.toString());

                          if (parsedDate != null) {
                            setState(() {
                              _selectedDate = parsedDate;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
