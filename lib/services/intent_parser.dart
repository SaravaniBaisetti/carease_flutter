import 'package:flutter/foundation.dart';

class IntentParser {
  /// Basic intent parsing for task confirmation
  /// It checks if the spoken text contains confirmation keywords across supported languages.
  static bool isConfirmation(String text) {
    if (text.isEmpty) return false;
    
    final lower = text.toLowerCase().trim();
    
    // Support English, Hindi, Telugu, Tamil, Bengali, Marathi, Urdu keywords for "taken" or "done" or "yes"
    final List<String> confirmKeywords = [
      // English
      'yes', 'yeah', 'done', 'taken', 'complete', 'completed', 'finished', 'yep', 'i did',
      // Hindi
      'haan', 'ha', 'ho gaya', 'le liya', 'kha liya', 'kar diya', 'liya', 'ho gya',
      'हाँ', 'हा', 'हो गया', 'ले लिया', 'खा लिया', 'कर दिया', 'लिया',
      // Telugu
      'avunu', 'cheshanu', 'chesanu', 'esukunna', 'vesukunna', 'teesukunna', 'tisukunna', 'ayipoyindi', 'ayipoyindhi',
      'అవును', 'చేశాను', 'వేసుకున్నా', 'తీసుకున్నా', 'అయిపోయింది',
      // Tamil
      'aama', 'mudinchu', 'mudinchuruchu', 'saaptachu', 'saptachu', 'eduthachu',
      'ஆமா', 'முடிஞ்சு', 'முடிஞ்சிருச்சு', 'சாப்டாச்சு', 'எடுத்தாச்சு',
      // Bengali
      'hyan', 'hଁa', 'kheyechi', 'korechi', 'hoyeche', 'niyechi', 
      'হ্যাঁ', 'খেয়েছি', 'করেছি', 'হয়েছে', 'নিয়েছি',
      // Marathi
      'ho', 'zala', 'kela', 'ghetla', 'ghyetla',
      'हो', 'झालं', 'केलं', 'घेतलं',
      // Urdu
      'jee', 'ji', 'haan', 'han', 'le liya hai', 'ho gaya hai',
      'جی', 'ہاں', 'لے لیا ہے', 'ہو گیا ہے'
    ];

    for (var keyword in confirmKeywords) {
      if (lower.contains(keyword)) {
        debugPrint("IntentParser: Recognized confirmation via keyword '$keyword' in text '$text'");
        return true;
      }
    }
    
    return false;
  }

  /// Parses dashboard queries like "what are my tasks" or "what are my medicines" or "help/sos"
  static String parseDashboardCommand(String text) {
    if (text.isEmpty) return 'unknown';
    
    final lower = text.toLowerCase().trim();
    
    final List<String> sosKeywords = [
       'sos', 'help', 'emergency', 'bachao', 'madad', 'sahayam', 'kapadandi',
       'உதவி', 'காப்பாற்றுங்கள்', // Tamil
       'సహాయం', 'కాపాడండి', // Telugu
       'बचाओ', 'मदद', // Hindi/Marathi
       'সাহায্য', 'বাঁচাও', // Bengali
       'بچاؤ', 'مدد' // Urdu 
    ];

    // Support English along with transliterated AND native scripts
    final List<String> taskKeywords = [
      'task', 'tasks', 'kaam', 'pani', 'kasa', 'velai', 'kaj', 'kam',
      'काम', // Hindi/Marathi
      'कार्य', // Hindi
      'పని', 'పనులు', // Telugu
      'வேலை', 'வேலைகள்', // Tamil
      'কাজ', // Bengali
      'کام' // Urdu
    ];
    
    final List<String> medKeywords = [
      'medicine', 'medicines', 'pill', 'tablet', 'dawa', 'dawaii', 'mandhu', 'marundhu', 'oushadh', 'osudh',
      'दवा', 'दवाई', // Hindi
      'औषध', // Marathi
      'మందు', 'మందులు', 'మాత్ర', 'మాత్రలు', // Telugu
      'மருந்து', 'மாத்திரை', // Tamil
      'ওষুধ', // Bengali
      'دوا' // Urdu
    ];

    for (var keyword in sosKeywords) {
       if (lower.contains(keyword)) return 'trigger_sos';
    }

    for (var keyword in taskKeywords) {
       if (lower.contains(keyword)) return 'read_tasks';
    }
    
    for (var keyword in medKeywords) {
       if (lower.contains(keyword)) return 'read_medicines';
    }
    
    return 'unknown';
  }
}
