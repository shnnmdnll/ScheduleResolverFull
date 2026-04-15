import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/task_model.dart';
import '../models/schedule_analysis.dart';

class AiScheduleService extends ChangeNotifier {
  ScheduleAnalysis? _currentAnalysis;
  bool _isLoading = false;
  String? _errorMessage;

  final String _apiKey = '';

  ScheduleAnalysis? get currentAnalysis => _currentAnalysis;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> analyzeSchedule(List<TaskModel> tasks) async {
    if (tasks.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    _currentAnalysis = null;
    notifyListeners();

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      final tasksJson = jsonEncode(tasks.map((t) => t.toJson()).toList());

      final prompt = '''
      You are an expert student scheduling assistant. 
      The user has provided the following tasks in JSON: $tasksJson

      Analyze the tasks, identify overlaps, and suggest a balanced schedule.
      
      IMPORTANT: You must provide exactly these 4 sections starting with '###':
      ### Detected Conflicts
      ### Ranked Tasks
      ### Recommended Schedule
      ### Explanation
      ''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      if (response.text != null && response.text!.isNotEmpty) {
        _currentAnalysis = _parseResponse(response.text!);
      } else {
        _errorMessage = "AI returned an empty response.";
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch AI data: $e';
      print("DEBUG ERROR: $e"); // Lalabas ito sa console mo
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ScheduleAnalysis _parseResponse(String fulltext) {
    String conflicts = "No conflicts detected.";
    String rankedTasks = "No tasks ranked.";
    String recommendations = "No recommendations provided.";
    String explanation = "No explanation provided.";

    // Hatiin ang text base sa '###'
    final sections = fulltext.split("###");

    for (var section in sections) {
      final trimmedSection = section.trim();

      if (trimmedSection.startsWith('Detected Conflicts')) {
        conflicts = trimmedSection.replaceFirst('Detected Conflicts', '').trim();
      } else if (trimmedSection.startsWith('Ranked Tasks')) {
        rankedTasks = trimmedSection.replaceFirst('Ranked Tasks', '').trim();
      } else if (trimmedSection.startsWith('Recommended Schedule')) {
        recommendations = trimmedSection.replaceFirst('Recommended Schedule', '').trim();
      } else if (trimmedSection.startsWith('Explanation')) {
        explanation = trimmedSection.replaceFirst('Explanation', '').trim();
      }
    }

    return ScheduleAnalysis(
      conflicts: conflicts,
      rankedTasks: rankedTasks,
      recommendationSchedule: recommendations,
      explanation: explanation,
    );
  }

  // Dagdag na function para i-clear ang error o analysis kung kailangan
  void clearAnalysis() {
    _currentAnalysis = null;
    _errorMessage = null;
    notifyListeners();
  }
}
