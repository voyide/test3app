import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..loadData()),
      ],
      child: const ProTestApp(),
    ),
  );
}

class ProTestApp extends StatelessWidget {
  const ProTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProTest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const MainNavigationScreen(),
    );
  }
}

// ==========================================
// MODELS
// ==========================================

class Question {
  final String id;
  final String category;
  final String text;
  final List<String> options;
  final int correctAnswerIndex;

  Question({
    required this.id,
    required this.category,
    required this.text,
    required this.options,
    required this.correctAnswerIndex,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      category: json['category'] ?? 'Uncategorized',
      text: json['text'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswerIndex: json['correctAnswerIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'text': text,
        'options': options,
        'correctAnswerIndex': correctAnswerIndex,
      };
}

class TestSession {
  final String category;
  final int score;
  final int totalQuestions;
  final int durationSeconds;
  final int timestamp;
  // FIX: Added for answer review functionality
  final List<Question> questions;
  final Map<String, int> userAnswers; // Key: Question ID, Value: User's selected index

  TestSession({
    required this.category,
    required this.score,
    required this.totalQuestions,
    required this.durationSeconds,
    required this.timestamp,
    required this.questions,
    required this.userAnswers,
  });

  factory TestSession.fromJson(Map<String, dynamic> json) {
    return TestSession(
      category: json['category'] ?? 'Unknown',
      score: json['score'] ?? 0,
      totalQuestions: json['totalQuestions'] ?? 0,
      durationSeconds: json['durationSeconds'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      questions: (json['questions'] as List<dynamic>?)?.map((q) => Question.fromJson(q)).toList() ?? [],
      userAnswers: Map<String, int>.from(json['userAnswers'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'score': score,
        'totalQuestions': totalQuestions,
        'durationSeconds': durationSeconds,
        'timestamp': timestamp,
        'questions': questions.map((q) => q.toJson()).toList(),
        'userAnswers': userAnswers,
      };
}

// ==========================================
// STATE MANAGEMENT (PROVIDER)
// ==========================================

class AppState extends ChangeNotifier {
  List<Question> _questions = [];
  List<TestSession> _sessions = [];
  bool _isLoading = true;

  List<Question> get questions => _questions;
  List<TestSession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final questionsJson = prefs.getString('questions');
    if (questionsJson != null) {
      _questions = (jsonDecode(questionsJson) as List).map((q) => Question.fromJson(q)).toList();
    } else {
      _loadDefaultQuestions();
    }

    final sessionsJson = prefs.getString('sessions');
    if (sessionsJson != null) {
      _sessions = (jsonDecode(sessionsJson) as List).map((s) => TestSession.fromJson(s)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('questions', jsonEncode(_questions.map((q) => q.toJson()).toList()));
    await prefs.setString('sessions', jsonEncode(_sessions.map((s) => s.toJson()).toList()));
  }

  // FIX: Prevents duplicate questions by using the question 'id' as a unique key.
  Future<bool> importQuestionsFromString(String jsonString) async {
    try {
      if (jsonString.trim().isEmpty) return false;
      
      final List<dynamic> decoded = jsonDecode(jsonString);
      final newQuestions = decoded.map((q) => Question.fromJson(q)).toList();

      // Create a map of existing questions for efficient lookup
      final Map<String, Question> existingQuestionsMap = {for (var q in _questions) q.id: q};

      for (var newQuestion in newQuestions) {
        existingQuestionsMap[newQuestion.id] = newQuestion; // Add new or update existing
      }

      _questions = existingQuestionsMap.values.toList(); // Convert back to a list
      
      await saveData();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error parsing JSON string or updating questions: $e");
      return false;
    }
  }

  void addSession(TestSession session) {
    _sessions.add(session);
    saveData();
    notifyListeners();
  }

  List<String> getCategories() {
    return _questions.map((q) => q.category).toSet().toList();
  }

  List<Question> getQuestionsByCategory(String category) {
    return _questions.where((q) => q.category == category).toList();
  }

  void _loadDefaultQuestions() {
    const String defaultJson = '''[
      {
        "id": "cs101",
        "category": "Computer Science",
        "text": "What is the time complexity of binary search?\\n\\n*Hint: It divides the search interval in half.*",
        "options":["O(1)", "O(n)", "O(log n)", "O(n^2)"],
        "correctAnswerIndex": 2
      },
      {
        "id": "math101",
        "category": "Mathematics",
        "text": "Evaluate the following:\\n\\n`2 + 2 * 2`",
        "options":["4", "6", "8", "10"],
        "correctAnswerIndex": 1
      }
    ]
    ''';
    _questions = (jsonDecode(defaultJson) as List).map((q) => Question.fromJson(q)).toList();
    saveData();
  }
}

// ==========================================
// UI SCREENS
// ==========================================

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [HomeScreen(), StatsScreen()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Tests'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Stats'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showImportDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste JSON'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
              hintText: 'Paste your JSON array here...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              bool success = await context.read<AppState>().importQuestionsFromString(controller.text);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? 'Questions imported/updated!' : 'Failed! Invalid JSON format.'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ));
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final categories = appState.getCategories();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Tests', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Paste JSON',
            icon: const Icon(Icons.paste),
            onPressed: () => _showImportDialog(context),
          ),
        ],
      ),
      body: appState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? const Center(child: Text('No questions found. Paste some JSON!'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.2),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final qCount = appState.getQuestionsByCategory(category).length;
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TestScreen(
                                category: category,
                                questions: appState.getQuestionsByCategory(category)..shuffle()),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.library_books, size: 40, color: Colors.deepPurple),
                              const SizedBox(height: 12),
                              Text(category, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('$qCount Questions', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class TestScreen extends StatefulWidget {
  final String category;
  final List<Question> questions;
  const TestScreen({super.key, required this.category, required this.questions});
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // Key: question index, Value: option index
  late Stopwatch _stopwatch;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => setState(() {}));
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _timer.cancel();
    super.dispose();
  }

  void _submitTest() {
    _stopwatch.stop();
    int score = 0;
    // Convert selected answers to a map of [QuestionID, AnswerIndex] for robust storage
    final Map<String, int> userAnswersMap = {};
    for (int i = 0; i < widget.questions.length; i++) {
      final question = widget.questions[i];
      if (_selectedAnswers.containsKey(i)) {
        userAnswersMap[question.id] = _selectedAnswers[i]!;
        if (_selectedAnswers[i] == question.correctAnswerIndex) {
          score++;
        }
      }
    }

    final session = TestSession(
      category: widget.category,
      score: score,
      totalQuestions: widget.questions.length,
      durationSeconds: _stopwatch.elapsed.inSeconds,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      questions: widget.questions,
      userAnswers: userAnswersMap,
    );
    context.read<AppState>().addSession(session);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(session: session)));
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeBgColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final codeTextColor = isDark ? Colors.grey.shade100 : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(_formatDuration(_stopwatch.elapsed), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_currentIndex + 1) / widget.questions.length),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Question ${_currentIndex + 1} of ${widget.questions.length}', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    MarkdownBody(
                      data: question.text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 18, height: 1.5),
                        code: TextStyle(backgroundColor: codeBgColor, color: codeTextColor, fontFamily: 'monospace', fontSize: 16),
                        codeblockDecoration: BoxDecoration(color: codeBgColor, borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...List.generate(question.options.length, (index) {
                      bool isSelected = _selectedAnswers[_currentIndex] == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: InkWell(
                          onTap: () => setState(() => _selectedAnswers[_currentIndex] = index),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).cardColor,
                              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : (isDark ? Colors.grey.shade700 : Colors.grey.shade300), width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Radio<int>(value: index, groupValue: _selectedAnswers[_currentIndex], onChanged: (val) => setState(() => _selectedAnswers[_currentIndex] = val!)),
                                Expanded(
                                  child: MarkdownBody(
                                    data: question.options[index],
                                    styleSheet: MarkdownStyleSheet(
                                      p: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                      code: TextStyle(backgroundColor: codeBgColor, color: codeTextColor, fontFamily: 'monospace', fontSize: 15),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null, child: const Text('Previous')),
                  if (_currentIndex < widget.questions.length - 1)
                    FilledButton(onPressed: () => setState(() => _currentIndex++), child: const Text('Next'))
                  else
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.green), onPressed: _submitTest, child: const Text('Submit Test')),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final TestSession session;
  const ResultScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    double percentage = session.totalQuestions > 0 ? (session.score / session.totalQuestions) * 100 : 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Test Result'), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(percentage >= 70 ? Icons.emoji_events : Icons.check_circle_outline, size: 100, color: percentage >= 70 ? Colors.amber : Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
              Text('You scored ${session.score} out of ${session.totalQuestions}', style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 16),
              Text('Time Taken: ${session.durationSeconds} seconds', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 48),
              // FIX: Added Review Answers button
              FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewScreen(session: session))),
                icon: const Icon(Icons.rate_review),
                label: const Text('Review Answers'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                icon: const Icon(Icons.home),
                label: const Text('Return to Home'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// FIX: New screen to review answers
class ReviewScreen extends StatelessWidget {
  final TestSession session;
  const ReviewScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Review: ${session.category}')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: session.questions.length,
        itemBuilder: (context, index) {
          final question = session.questions[index];
          final userAnswerIndex = session.userAnswers[question.id];
          final bool isCorrect = userAnswerIndex == question.correctAnswerIndex;

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Question ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Divider(height: 20),
                  MarkdownBody(data: question.text),
                  const SizedBox(height: 24),
                  ...List.generate(question.options.length, (optIndex) {
                    final bool isCorrectAnswer = optIndex == question.correctAnswerIndex;
                    final bool isSelectedAnswer = optIndex == userAnswerIndex;

                    Color? tileColor;
                    Icon? trailingIcon;

                    if (isCorrectAnswer) {
                      tileColor = Colors.green.withOpacity(0.15);
                      trailingIcon = const Icon(Icons.check_circle, color: Colors.green);
                    } else if (isSelectedAnswer && !isCorrectAnswer) {
                      tileColor = Colors.red.withOpacity(0.15);
                      trailingIcon = const Icon(Icons.cancel, color: Colors.red);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: tileColor,
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(question.options[optIndex]),
                        trailing: trailingIcon,
                      ),
                    );
                  }),
                  if (userAnswerIndex == null)
                    const Text('Not Answered', style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  // ... (Stats screen code remains unchanged)
  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<AppState>().sessions;

    if (sessions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Advanced Stats')),
        body: const Center(child: Text('Take some tests to see your stats here!')),
      );
    }

    int totalTests = sessions.length;
    int totalQuestionsAttempted = sessions.fold(0, (sum, s) => sum + s.totalQuestions);
    int totalCorrect = sessions.fold(0, (sum, s) => sum + s.score);
    double globalAccuracy = totalQuestionsAttempted == 0 ? 0 : (totalCorrect / totalQuestionsAttempted) * 100;
    int totalTimeSeconds = sessions.fold(0, (sum, s) => sum + s.durationSeconds);

    Map<String, List<TestSession>> sessionsByCategory = {};
    for (var s in sessions) {
      sessionsByCategory.putIfAbsent(s.category, () =>[]).add(s);
    }

    List<BarChartGroupData> barGroups =[];
    int xIndex = 0;
    List<String> categoryLabels =[];

    sessionsByCategory.forEach((category, catSessions) {
      int catAttempted = catSessions.fold(0, (sum, s) => sum + s.totalQuestions);
      int catCorrect = catSessions.fold(0, (sum, s) => sum + s.score);
      double accuracy = catAttempted == 0 ? 0 : (catCorrect / catAttempted) * 100;
      barGroups.add(BarChartGroupData(x: xIndex, barRods:[BarChartRodData(toY: accuracy, color: Colors.deepPurple, width: 20, borderRadius: BorderRadius.circular(4))]));
      categoryLabels.add(category);
      xIndex++;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Stats', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children:[
                Expanded(child: _buildStatCard(context, 'Total Tests', '$totalTests', Icons.quiz)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(context, 'Accuracy', '${globalAccuracy.toStringAsFixed(1)}%', Icons.track_changes)),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatCard(context, 'Total Time Spent', '${(totalTimeSeconds / 60).toStringAsFixed(1)} minutes', Icons.timer, isFullWidth: true),
            const SizedBox(height: 32),
            const Text('Accuracy by Category', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => Colors.blueGrey)),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (double value, TitleMeta meta) {
                    if (value.toInt() >= categoryLabels.length) return const SizedBox.shrink();
                    String text = categoryLabels[value.toInt()];
                    if (text.length > 8) text = '${text.substring(0, 6)}..';
                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(text, style: const TextStyle(fontSize: 10)));
                  })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text('${value.toInt()}%', style: const TextStyle(fontSize: 12)))),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              )),
            ),
            const SizedBox(height: 32),
            const Text('Recent Sessions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sessions.reversed.take(5).length,
              itemBuilder: (context, index) {
                final session = sessions.reversed.toList()[index];
                final date = DateTime.fromMillisecondsSinceEpoch(session.timestamp);
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.history)),
                  title: Text(session.category),
                  subtitle: Text(DateFormat('MMM dd, yyyy - hh:mm a').format(date)),
                  trailing: Text('${session.score}/${session.totalQuestions}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, {bool isFullWidth = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
