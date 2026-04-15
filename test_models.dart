import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'AIzaSyAJ9kBIX2hwHwh7-LGe4cx3oNlZmVpju_0';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=' + apiKey);
  
  try {
    print('Testing models listing...');
    final response = await http.get(url);
    print('Status: ' + response.statusCode.toString());
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final models = json['models'] as List;
      for (var m in models) {
        print(m['name']);
      }
    } else {
      print('Body: ' + response.body);
    }
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
