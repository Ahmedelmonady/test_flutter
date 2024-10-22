import 'dart:convert';

import '../../models/responses/bot_settings_response.dart';
import '../utils/constants.dart';
import '../utils/header_generator.dart';
import 'package:http/http.dart' as http;

Future<BotSettingsResponse> getBotSettingsRequest(String apiKey, String lang) async {
  const url = '$baseUrl$botSettingsEndpoint';

  final response = await http.get(
    Uri.parse(url),
    headers: getRequestHeaders(apiKey, lang),
  );
  
  // Check for successful response
  if (response.statusCode == 200) {
    print(response.body);
    // Parse the JSON response and return a PlayerRegisterResponse object
    final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
    return BotSettingsResponse.fromJson(jsonMap);
  } else {
    // Handle error based on status code or throw an exception
    throw Exception(
        'Failed to get bot settings. Status code: ${response.statusCode}');
  }
}
