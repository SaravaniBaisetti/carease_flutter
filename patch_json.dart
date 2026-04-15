import 'dart:convert';
import 'dart:io';

void main() {
  final Map<String, Map<String, String>> translations = {
    'en': {
        "ai_assistant_listening": "AI Assistant Listening...",
        "how_can_i_help": "How can I help you?",
        "you_have": "You have",
        "did_not_understand": "I didn't understand. Try asking for your tasks or medicines.",
        "ai_voice_assistant": "AI Voice Assistant"
    },
    'hi': {
        "ai_assistant_listening": "एआई सहायक सुन रहा है...",
        "how_can_i_help": "मैं आपकी कैसे मदद कर सकता हूँ?",
        "you_have": "आपके",
        "did_not_understand": "मुझे समझ नहीं आया। अपने कार्यों या दवाओं के बारे में पूछने का प्रयास करें।",
        "ai_voice_assistant": "एआई वॉयस असिस्टेंट"
    },
    'te': {
        "ai_assistant_listening": "AI అసిస్టెంట్ వింటుంది...",
        "how_can_i_help": "నేను మీకు ఎలా సహాయం చేయగలను?",
        "you_have": "మీకు",
        "did_not_understand": "నాకు అర్థం కాలేదు. మీ పనులు లేదా మందుల గురించి అడగండి.",
        "ai_voice_assistant": "AI వాయిస్ అసిస్టెంట్"
    },
    'ta': {
        "ai_assistant_listening": "AI உதவியாளர் கேட்கிறார்...",
        "how_can_i_help": "நான் உங்களுக்கு எப்படி உதவ முடியும்?",
        "you_have": "உங்களுக்கு",
        "did_not_understand": "எனக்கு புரியவில்லை. உங்கள் வேலைகள் அல்லது மருந்துகள் பற்றி கேட்க முயற்சிக்கவும்.",
        "ai_voice_assistant": "AI குரல் உதவியாளர்"
    },
    'bn': {
        "ai_assistant_listening": "এআই সহকারী শুনছে...",
        "how_can_i_help": "আমি আপনাকে কীভাবে সাহায্য করতে পারি?",
        "you_have": "আপনার আছে",
        "did_not_understand": "আমি বুঝতে পারিনি। আপনার কাজ বা ওষুধের জন্য জিজ্ঞাসা করার চেষ্টা করুন।",
        "ai_voice_assistant": "এআই ভয়েস সহকারী"
    },
    'mr': {
        "ai_assistant_listening": "एआय सहाय्यक ऐकत आहे...",
        "how_can_i_help": "मी तुम्हाला कशी मदत करू शकतो?",
        "you_have": "तुमच्याकडे",
        "did_not_understand": "मला समजले नाही. आपली कामे किंवा औषधांबद्दल विचारण्याचा प्रयत्न करा.",
        "ai_voice_assistant": "एआय व्हॉइस असिस्टंट"
    },
    'ur': {
        "ai_assistant_listening": "اے آئی اسسٹنٹ سن رہا ہے...",
        "how_can_i_help": "میں آپ کی کیسے مدد کر سکتا ہوں؟",
        "you_have": "آپ کے پاس",
        "did_not_understand": "مجھے سمجھ نہیں آیا۔ اپنے کاموں یا ادویات کے بارے میں پوچھنے کی کوشش کریں۔",
        "ai_voice_assistant": "اے آئی وائس اسسٹنٹ"
    }
  };

  final basePath = "assets/translations";

  for (var entry in translations.entries) {
    var lang = entry.key;
    var additions = entry.value;
    var file = File(basePath + '/' + lang + '.json');
    if (file.existsSync()) {
      var content = file.readAsStringSync();
      Map<String, dynamic> data = jsonDecode(content);
      bool updated = false;
      for (var addKey in additions.keys) {
        if (!data.containsKey(addKey)) {
          data[addKey] = additions[addKey];
          updated = true;
        }
      }
      if (updated) {
        var encoder = const JsonEncoder.withIndent('  ');
        file.writeAsStringSync(encoder.convert(data));
        print("Updated " + lang + ".json");
      } else {
        print("No missing keys in " + lang + ".json");
      }
    } else {
      print("File not found: " + lang + ".json");
    }
  }
}
