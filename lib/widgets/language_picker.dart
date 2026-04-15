import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  void _showLanguageSelector(BuildContext context) {
    final Map<String, Locale> supportedLanguages = {
      'English': const Locale('en'),
      'हिंदी (Hindi)': const Locale('hi'),
      'తెలుగు (Telugu)': const Locale('te'),
      'தமிழ் (Tamil)': const Locale('ta'),
      'বাংলা (Bengali)': const Locale('bn'),
      'मराठी (Marathi)': const Locale('mr'),
      'اردو (Urdu)': const Locale('ur'),
    };

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('select_language'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: supportedLanguages.length,
                  itemBuilder: (context, index) {
                    String languageName = supportedLanguages.keys.elementAt(index);
                    Locale locale = supportedLanguages.values.elementAt(index);
                    bool isSelected = context.locale == locale;

                    return ListTile(
                      title: Text(
                        languageName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        context.setLocale(locale);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.language),
      tooltip: tr('select_language'),
      onPressed: () => _showLanguageSelector(context),
    );
  }
}
