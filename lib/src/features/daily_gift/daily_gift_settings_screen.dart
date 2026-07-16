import 'package:flutter/material.dart';

import 'daily_gift_service.dart';

class DailyGiftSettingsScreen extends StatefulWidget {
  const DailyGiftSettingsScreen({super.key});

  @override
  State<DailyGiftSettingsScreen> createState() =>
      _DailyGiftSettingsScreenState();
}

class _DailyGiftSettingsScreenState extends State<DailyGiftSettingsScreen> {
  final _service = DailyGiftService();
  DailyGiftSettings _settings = DailyGiftSettings.defaults;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _service.loadSettings();
    final gift = await _service.grantTodayIfDue();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
    if (gift != null) _showGiftSnack(gift);
  }

  Future<void> _save(DailyGiftSettings settings) async {
    setState(() => _saving = true);
    await _service.saveSettings(settings);
    final gift = await _service.grantTodayIfDue();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('선물 시간을 ${settings.timeLabel}로 저장했어요.')),
    );
    if (gift != null) _showGiftSnack(gift);
  }

  Future<void> _toggleEnabled(bool value) async {
    await _save(_settings.copyWith(enabled: value));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _settings.hour, minute: _settings.minute),
    );
    if (picked == null) return;
    await _save(
      _settings.copyWith(hour: picked.hour, minute: picked.minute),
    );
  }

  Future<void> _grantTestGift() async {
    final gift = await _service.grantTestGift();
    if (!mounted) return;
    _showGiftSnack(gift);
  }

  void _showGiftSnack(DailyGift gift) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${gift.title}을(를) 받았어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('선물 시간')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    value: _settings.enabled,
                    onChanged: _saving ? null : _toggleEnabled,
                    secondary: const Icon(Icons.card_giftcard_rounded),
                    title: const Text('매일 선물 받기'),
                    subtitle: const Text('정한 시간이 지나면 오늘의 작업실 선물이 도착해요.'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('선물 도착 시간'),
                    subtitle: Text(_settings.timeLabel),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    enabled: !_saving,
                    onTap: _pickTime,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '앱이 백그라운드에서 항상 실행되지는 않기 때문에, 선물은 앱을 열거나 보관함에 들어올 때 오늘 시간이 지났는지 확인한 뒤 한 번만 지급됩니다.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _grantTestGift,
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('테스트 선물 받기'),
                ),
              ],
            ),
    );
  }
}
