import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({
    required this.ocrEnabled,
    required this.defaultExportFormat,
    required this.defaultPageSize,
    required this.defaultColorMode,
    required this.encryptPdf,
  });

  final bool ocrEnabled;
  final String defaultExportFormat;
  final String defaultPageSize;
  final String defaultColorMode;
  final bool encryptPdf;

  SettingsState copyWith({
    bool? ocrEnabled,
    String? defaultExportFormat,
    String? defaultPageSize,
    String? defaultColorMode,
    bool? encryptPdf,
  }) {
    return SettingsState(
      ocrEnabled: ocrEnabled ?? this.ocrEnabled,
      defaultExportFormat: defaultExportFormat ?? this.defaultExportFormat,
      defaultPageSize: defaultPageSize ?? this.defaultPageSize,
      defaultColorMode: defaultColorMode ?? this.defaultColorMode,
      encryptPdf: encryptPdf ?? this.encryptPdf,
    );
  }
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  late SharedPreferences _prefs;

  @override
  Future<SettingsState> build() async {
    _prefs = await SharedPreferences.getInstance();
    return SettingsState(
      ocrEnabled: _prefs.getBool('ocrEnabled') ?? true,
      defaultExportFormat: _prefs.getString('defaultExportFormat') ?? 'PDF',
      defaultPageSize: _prefs.getString('defaultPageSize') ?? 'A4',
      defaultColorMode: _prefs.getString('defaultColorMode') ?? 'Color',
      encryptPdf: _prefs.getBool('encryptPdf') ?? false,
    );
  }

  Future<void> updateOcr(bool value) async {
    await _prefs.setBool('ocrEnabled', value);
    state = AsyncData(state.value!.copyWith(ocrEnabled: value));
  }

  Future<void> updateExportFormat(String value) async {
    await _prefs.setString('defaultExportFormat', value);
    state = AsyncData(state.value!.copyWith(defaultExportFormat: value));
  }

  Future<void> updatePageSize(String value) async {
    await _prefs.setString('defaultPageSize', value);
    state = AsyncData(state.value!.copyWith(defaultPageSize: value));
  }

  Future<void> updateColorMode(String value) async {
    await _prefs.setString('defaultColorMode', value);
    state = AsyncData(state.value!.copyWith(defaultColorMode: value));
  }

  Future<void> updateEncryptPdf(bool value) async {
    await _prefs.setBool('encryptPdf', value);
    state = AsyncData(state.value!.copyWith(encryptPdf: value));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
