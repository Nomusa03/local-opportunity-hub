import 'dart:convert';

import 'package:http/http.dart' as http;

class PublicHolidayService {
  // Retrieve South African public holidays
  Future<List<dynamic>> getPublicHolidays() async {
    final year = DateTime.now().year;

    final url = Uri.parse(
      'https://date.nager.at/api/v3/PublicHolidays/$year/ZA',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          return data;
        }

        throw Exception('Unexpected response format');
      } else {
        throw Exception(
          'Failed to load public holidays: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Unable to retrieve public holidays: $e');
    }
  }
}
