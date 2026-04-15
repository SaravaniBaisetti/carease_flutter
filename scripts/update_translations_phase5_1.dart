import 'dart:convert';
import 'dart:io';

void main() async {
  final Map<String, Map<String, String>> translations = {
    'en': {
      'medical_conditions': "Medical Conditions",
    },
    'hi': {
      'medical_conditions': "चिकित्सीय स्थितियाँ",
    },
    'te': {
      'medical_conditions': "వైద్య పరిస్థితులు",
    },
    'ta': {
      'medical_conditions': "மருத்துவ நிலைமைகள்",
    },
    'bn': {
      'medical_conditions': "চিকিৎসাগত অবস্থা",
    },
    'mr': {
      'medical_conditions': "वैद्यकीय परिस्थिती",
    },
    'ur': {
      'medical_conditions': "طبی حالات",
    }
  };

  final targetDir = Directory("c:\\\\Users\\\\SAI SARVANI\\\\OneDrive\\\\Desktop\\\\projects\\\\careasen\\\\assets\\\\translations");
  
  for (var entry in translations.entries) {
    final file = File('${targetDir.path}\\\\${entry.key}.json');
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(content);
        
        for (var newEntry in entry.value.entries) {
          jsonMap[newEntry.key] = newEntry.value;
        }
        
        const encoder = JsonEncoder.withIndent('  ');
        final updatedContent = encoder.convert(jsonMap);
        await file.writeAsString(updatedContent);
        print("Updated ${entry.key}.json successfully Phase 5.1.");
      } catch (e) {
        print("Error parsing or writing ${entry.key}.json: $e");
      }
    } else {
      print("File not found: ${file.path}");
    }
  }
}
