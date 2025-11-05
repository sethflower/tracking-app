import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_barcode_listener/flutter_barcode_listener.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'utils/access_utils.dart';
import 'utils/offline_queue.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final TextEditingController _boxController = TextEditingController();
  final TextEditingController _ttnController = TextEditingController();
  final FocusNode _boxFocus = FocusNode();
  final FocusNode _ttnFocus = FocusNode();

  bool _isBoxStep = true;
  bool _isLoading = false;
  bool _isOnline = true; // 🟢 состояние соединения
  String _status = '';
  String _userName = 'operator';

  String _roleLabel = '';
  Color _roleColor = Colors.grey;

  late final Connectivity _connectivity;
  late final Stream<List<ConnectivityResult>> _connectivityStream;

  @override
  void initState() {
    super.initState();
    _loadUserAndRole();

    _connectivity = Connectivity();
    _connectivityStream = _connectivity.onConnectivityChanged;

    // Подписываемся на изменения соединения
    _connectivityStream.listen((List<ConnectivityResult> results) async {
  final online = results.isNotEmpty && results.first != ConnectivityResult.none;
      if (mounted) {
        setState(() => _isOnline = online);
      }
      if (online) {
        await OfflineQueue.syncPending(); // 🔁 при возврате сети — синхронизация
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boxFocus.requestFocus();
    });
  }

  Future<void> _loadUserAndRole() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_name') ?? 'operator';
    final roleInfo = await getUserAccessInfo();

    setState(() {
      _userName = savedName;
      _roleLabel = roleInfo['label'];
      _roleColor = roleInfo['color'];
    });
  }

  @override
  void dispose() {
    _boxController.dispose();
    _ttnController.dispose();
    _boxFocus.dispose();
    _ttnFocus.dispose();
    super.dispose();
  }

  Future<void> playSuccessSound() async => SystemSound.play(SystemSoundType.click);
  Future<void> playErrorSound() async => SystemSound.play(SystemSoundType.alert);

  Future<void> _sendRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userName = prefs.getString('user_name') ?? _userName;

    final boxid = _boxController.text.trim();
    final ttn = _ttnController.text.trim();

    if (boxid.isEmpty || ttn.isEmpty) return;

    setState(() => _isLoading = true);

    final record = {'user_name': userName, 'boxid': boxid, 'ttn': ttn};

    try {
      if (!_isOnline || token == null) throw Exception("Offline");

      final uri = Uri.parse('https://tracking-api-b4jb.onrender.com/add_record');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(record),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final note = data['note'] ?? '';

        if (note.isEmpty) {
          await playSuccessSound();
          setState(() => _status = '✅ Успішно додано');
        } else {
          await playErrorSound();
          setState(() => _status = '⚠️ Дублікат: $note');
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (_) {
      // 💾 Офлайн-сохранение
      await OfflineQueue.addRecord(record);
      await playErrorSound();
      setState(() => _status = '📦 Збережено локально (офлайн)');
    } finally {
      await OfflineQueue.syncPending();
      _boxController.clear();
      _ttnController.clear();
      setState(() {
        _isBoxStep = true;
        _isLoading = false;
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        _boxFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: BarcodeKeyboardListener(
        bufferDuration: const Duration(milliseconds: 200),
        onBarcodeScanned: (code) {
          if (_isBoxStep) {
            _boxController.text = code;
            setState(() => _isBoxStep = false);
            _ttnFocus.requestFocus();
          } else {
            _ttnController.text = code;
            _sendRecord();
          }
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🔹 Индикатор состояния сети
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: _isOnline ? Colors.green.shade600 : Colors.red.shade600,
                padding: const EdgeInsets.all(6),
                child: Text(
                  _isOnline ? '🟢 Підключення активне' : '🔴 Немає зв’язку з сервером',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),

              // Панель состояния
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Оператор: $_userName',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                            Text(_roleLabel,
                                style: TextStyle(
                                  color: _roleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                )),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.qr_code_scanner, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          _isBoxStep ? 'BoxID' : 'ТТН',
                          style: TextStyle(
                            fontSize: 16,
                            color: _isBoxStep ? Colors.blueAccent : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Кнопки
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.blueAccent),
                    tooltip: 'Переглянути історію',
                    onPressed: () => Navigator.pushNamed(context, '/history'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.error_outline, color: Colors.orangeAccent),
                    tooltip: 'Переглянути помилки',
                    onPressed: () => Navigator.pushNamed(context, '/errors'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    tooltip: 'Вийти з акаунту',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Підтвердження виходу'),
                          content: const Text('Ви впевнені, що хочете вийти з акаунту?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Скасувати'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Вийти'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        }
                      }
                    },
                  ),
                ],
              ),

              // Основная часть
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isBoxStep ? 'Сканування BoxID' : 'Сканування ТТН',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 40),
                              TextField(
                                controller: _isBoxStep ? _boxController : _ttnController,
                                focusNode: _isBoxStep ? _boxFocus : _ttnFocus,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 20),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Введіть або відскануйте',
                                ),
                                onSubmitted: (_) {
                                  if (_isBoxStep) {
                                    setState(() => _isBoxStep = false);
                                    _ttnFocus.requestFocus();
                                  } else {
                                    _sendRecord();
                                  }
                                },
                              ),
                              const SizedBox(height: 40),
                              Text(
                                _status,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
