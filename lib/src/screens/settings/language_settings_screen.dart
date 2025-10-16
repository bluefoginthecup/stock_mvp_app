import 'package:provider/provider.dart';
import '../../app/lang_controller.dart';
import '../../l10n/l10n.dart';
import '../../ui/common/ui.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangController>();
    final current = lang.locale?.languageCode; // 'ko' | 'en' | null

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).settings_language_title)),
      body: ListView(
        children: [
          RadioListTile<String?>(
            title: Text(context.t.settings_language_system),
            value: null,
            groupValue: current,
            onChanged: (_) => lang.setLocale(null),
          ),
          RadioListTile<String?>(
            title: Text(context.t.settings_language_korean),
            value: 'ko',
            groupValue: current,
            onChanged: (_) => lang.setLocale(const Locale('ko')),
          ),
          RadioListTile<String?>(
            title: Text(context.t.settings_language_english),
            value: 'en',
            groupValue: current,
            onChanged: (_) => lang.setLocale(const Locale('en')),
          ),
          // 스페인어 추가 시:
          RadioListTile<String?>(
            title: Text(context.t.settings_language_spanish),
            value: 'es',
            groupValue: current,
            onChanged: (_) => lang.setLocale(const Locale('es')),
          ),
        ],
      ),
    );
  }
}
