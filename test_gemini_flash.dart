import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  const apiKey = 'AIzaSyAJ9kBIX2hwHwh7-LGe4cx3oNlZmVpju_0';

  final tools = [
    Tool(functionDeclarations: [
      FunctionDeclaration(
        'trigger_sos',
        'Trigger an emergency SOS alert immediately to notify the caregiver.',
        Schema(SchemaType.object, properties: {}),
      ),
      FunctionDeclaration(
        'open_medicines',
        'Opens the medicines screen on the device so the elder can view their medicines visually.',
        Schema(SchemaType.object, properties: {}),
      ),
    ])
  ];

  final model = GenerativeModel(
    model: 'gemini-flash-latest',
    apiKey: apiKey,
    tools: tools,
  );
  
  final chat = model.startChat();
  
  try {
    print("Testing connection with gemini-flash-latest...");
    var response = await chat.sendMessage(Content.text("Hello"));
    print("Response: " + (response.text ?? 'null'));
  } catch (e, stack) {
    print("Error occurred: " + e.toString());
    print(stack);
  }
}
