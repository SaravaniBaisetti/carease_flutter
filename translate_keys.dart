import 'dart:io';
import 'dart:convert';

void main() async {
  final Map<String, Map<String, String>> translations = {
    "en": {"good_morning": "Good morning", "good_afternoon": "Good afternoon", "good_evening": "Good evening", "tap_to_record": "Tap to record how you feel"},
    "hi": {"good_morning": "सुप्रभात", "good_afternoon": "शुभ दोपहर", "good_evening": "शुभ संध्या", "tap_to_record": "कैसा महसूस कर रहे हैं, दर्ज करने के लिए टैप करें"},
    "te": {"good_morning": "శుభోదయం", "good_afternoon": "శుభ మధ్యాహ్నం", "good_evening": "శుభ సాయంత్రం", "tap_to_record": "మీరు ఎలా భావిస్తున్నారో రికార్డ్ చేయడానికి నొక్కండి"},
    "ta": {"good_morning": "காலை வணக்கம்", "good_afternoon": "மதிய வணக்கம்", "good_evening": "மாலை வணக்கம்", "tap_to_record": "நீங்கள் எப்படி உணர்கிறீர்கள் என்பதை பதிவு செய்ய தட்டவும்"},
    "bn": {"good_morning": "সুপ্রভাত", "good_afternoon": "শুভ বিকাল", "good_evening": "শুভ সন্ধ্যা", "tap_to_record": "আপনি কেমন অনুভব করছেন তা রেকর্ড করতে ট্যাপ করুন"},
    "mr": {"good_morning": "शुभ प्रभात", "good_afternoon": "शुभ दुपार", "good_evening": "शुभ संध्याकाळ", "tap_to_record": "तुम्हाला कसे वाटत आहे हे नोंदवण्यासाठी टॅप करा"},
    "ur": {"good_morning": "صبح بخیر", "good_afternoon": "دوپہر بخیر", "good_evening": "شام بخیر", "tap_to_record": "بتائیں کہ آپ کیسا محسوس کر رہے ہیں"}
  };

  final dir = Directory('assets/translations');
  
  translations.forEach((lang, data) {
    final file = File('${dir.path}/$lang.json');
    if (file.existsSync()) {
      var content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      data.forEach((key, value) {
        content[key] = value;
      });
      // Pretty print JSON
      var encoder = const JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(content));
    }
  });
}
