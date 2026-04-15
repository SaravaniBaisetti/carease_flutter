import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  const apiKey = 'AIzaSyAJ9kBIX2hwHwh7-LGe4cx3oNlZmVpju_0';
  final model = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
  final chat = model.startChat();
  try {
    print("Testing connection...");
    var response = await chat.sendMessage(Content.text("Hello"));
    print("Response: " + (response.text ?? 'null'));
  } catch (e, stack) {
    print("Error occurred:");
    print(e);
  }
}
