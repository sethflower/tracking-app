import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserNameScreen extends StatefulWidget {
  const UserNameScreen({super.key});

  @override
  State<UserNameScreen> createState() => _UserNameScreenState();
}

class _UserNameScreenState extends State<UserNameScreen> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _saveAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/scanner');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Введіть ім’я користувача',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                TextField(
  controller: _nameController,
  textAlign: TextAlign.center,
  style: const TextStyle(fontSize: 20),
  textInputAction: TextInputAction.done,
  enableSuggestions: true,
  autocorrect: true,
  keyboardType: TextInputType.name,
  textCapitalization: TextCapitalization.words,
  decoration: const InputDecoration(
    border: OutlineInputBorder(),
    hintText: 'Ваше ім’я (можна кирилицею)',
  ),
  onSubmitted: (_) => _saveAndContinue(),
),

                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  ),
                  child: const Text('Продовжити', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
