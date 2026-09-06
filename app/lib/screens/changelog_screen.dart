// Экран истории обновлений и списка изменений (Changelog)
// Загружает актуальные данные напрямую из GitHub Releases в режиме реального времени
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ReleaseModel {
  final String tag;
  final String title;
  final String publishedAt;
  final String rawBody;
  final String htmlUrl;
  final List<ReleaseAsset> assets;
  final bool isCurrent;

  const ReleaseModel({
    required this.tag,
    required this.title,
    required this.publishedAt,
    required this.rawBody,
    required this.htmlUrl,
    required this.assets,
    this.isCurrent = false,
  });

  factory ReleaseModel.fromJson(Map<String, dynamic> json, {String currentVersion = '1.0.3'}) {
    final tag = (json['tag_name'] ?? '').toString().replaceAll('v', '').trim();
    final title = json['name']?.toString() ?? 'Версия $tag';
    final published = json['published_at']?.toString() ?? '';
    final body = json['body']?.toString() ?? '';
    final html = json['html_url']?.toString() ?? 'https://github.com/yearningss/rii-schedule-bot/releases';

    final assetsList = <ReleaseAsset>[];
    if (json['assets'] is List) {
      for (final a in json['assets']) {
        if (a is Map) {
          assetsList.add(ReleaseAsset(
            name: a['name']?.toString() ?? 'Файл',
            sizeBytes: (a['size'] is num) ? (a['size'] as num).toInt() : 0,
            downloadUrl: a['download_url']?.toString() ?? '',
          ));
        }
      }
    }

    final isCur = tag.isNotEmpty && tag == currentVersion;

    return ReleaseModel(
      tag: tag,
      title: title,
      publishedAt: published,
      rawBody: body,
      htmlUrl: html,
      assets: assetsList,
      isCurrent: isCur,
    );
  }
}

class ReleaseAsset {
  final String name;
  final int sizeBytes;
  final String downloadUrl;

  const ReleaseAsset({
    required this.name,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  String get formattedSize {
    if (sizeBytes <= 0) return '';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} МБ';
  }
}

class ChangelogScreen extends StatefulWidget {
  final ApiService? api;

  const ChangelogScreen({super.key, this.api});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  late final ApiService _api;
  bool _isLoading = true;
  String? _errorMessage;
  List<ReleaseModel> _releases = [];
  bool _isFromCache = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ApiService();
    _loadReleases();
  }

  Future<void> _loadReleases({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final rawList = await _api.getChangelog();
      if (rawList.isNotEmpty) {
        final parsed = rawList
            .map((item) => ReleaseModel.fromJson(item, currentVersion: AppInfo.versionName))
            .toList();

        if (mounted) {
          setState(() {
            _releases = parsed;
            _isLoading = false;
            _isFromCache = false;
            _errorMessage = null;
          });
        }
        return;
      }
    } catch (_) {}

    // Если сеть недоступна, используем резервную встроенную историю
    if (mounted) {
      setState(() {
        _releases = _fallbackHistory();
        _isLoading = false;
        _isFromCache = true;
        _errorMessage = null;
      });
    }
  }

  List<ReleaseModel> _fallbackHistory() {
    return [
      ReleaseModel(
        tag: '1.0.3',
        title: 'Релиз v1.0.3 (сборка 4)',
        publishedAt: '2026-09-06T05:18:11Z',
        isCurrent: true,
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.3',
        rawBody: '''* Исправлен расчет и отображение расписания в субботу и воскресенье в приложении и виджете
* В выходные виджет и приложение автоматически рассчитывают пары на понедельник следующей недели
* Запрос разрешения на отправку системных уведомлений при запуске (Android 13+)
* Унификация версий в настройках и интеграция динамического Changelog
* Официальная цифровая подпись разработчика для доверия Google Play Protect''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 55597479,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.3/RiiSchedule.apk',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.2',
        title: 'Релиз v1.0.2 (сборка 3)',
        publishedAt: '2026-09-05T10:21:51Z',
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.2',
        rawBody: '''* Новый фирменный скругленный логотип приложения РИИ
* Адаптивные векторные и растровые иконки высокой четкости для Android и iOS
* Оптимизация памяти сборки Gradle и отключение устаревшего Jetifier
* Подготовка графических карточек и баннеров для RuStore''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56199315,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.2/RiiSchedule.apk',
          ),
        ],
      ),
      ReleaseModel(
        tag: '1.0.1',
        title: 'Релиз v1.0.1 (сборка 2)',
        publishedAt: '2026-09-05T09:54:18Z',
        htmlUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/tag/v1.0.1',
        rawBody: '''* Нативный виджет расписания для рабочего стола Android (RemoteViews)
* Отображение текущей и следующей пары, времени перемены и аудитории
* Авторизация через Telegram-бота (@rubinst_bot) и синхронизация профиля
* Проверка обновлений приложения через сервер института''',
        assets: [
          const ReleaseAsset(
            name: 'RiiSchedule.apk',
            sizeBytes: 56199000,
            downloadUrl: 'https://github.com/yearningss/rii-schedule-bot/releases/download/v1.0.1/RiiSchedule.apk',
          ),
        ],
      ),
    ];
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day.$month.$year, $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  List<String> _parseBodyLines(String raw) {
    if (raw.trim().isEmpty) return ['Улучшения стабильности и исправления ошибок.'];
    final lines = raw.split('\n');
    final result = <String>[];
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      // Пропускаем технические служебные заголовки
      if (trimmed.startsWith('### Файлы для загрузки') ||
          trimmed.startsWith('### Files') ||
          trimmed.startsWith('### Assets')) {
        break;
      }
      if (trimmed.startsWith('#')) {
        final heading = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
        if (heading.isNotEmpty) result.add('__HEADING__:$heading');
        continue;
      }
      // Очищаем маркер списка
      final clean = trimmed
          .replaceAll(RegExp(r'^[\*\-\+]\s*'), '')
          .replaceAll('**', '')
          .trim();
      if (clean.isNotEmpty) {
        result.add(clean);
      }
    }
    return result.isEmpty ? ['Улучшения стабильности и исправления ошибок.'] : result;
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E232D) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(
        title: const Text('История изменений'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Открыть GitHub',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => _launchUrl('https://github.com/yearningss/rii-schedule-bot/releases'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadReleases(isRefresh: true),
        color: const Color(0xFF2563EB),
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2563EB)),
                    SizedBox(height: 16),
                    Text(
                      'Загрузка реальной истории с GitHub...',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            : _releases.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Не удалось загрузить историю изменений',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Проверьте подключение к интернету и повторите попытку.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => _loadReleases(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Повторить'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _releases.length + 1,
                    itemBuilder: (context, idx) {
                      if (idx == 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF19202C) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isFromCache ? Icons.storage_rounded : Icons.check_circle_outline_rounded,
                                size: 18,
                                color: _isFromCache ? Colors.amber : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isFromCache
                                      ? 'Офлайн-режим (встроенная история). Потяните вниз для обновления.'
                                      : 'Данные синхронизированы в реальном времени с GitHub Releases.',
                                  style: TextStyle(fontSize: 12, color: subColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final item = _releases[idx - 1];
                      final lines = _parseBodyLines(item.rawBody);
                      ReleaseAsset? apkAsset;
                      for (final a in item.assets) {
                        if (a.name.endsWith('.apk') && !a.name.contains('debug')) {
                          apkAsset = a;
                          break;
                        }
                      }
                      if (apkAsset == null && item.assets.isNotEmpty) {
                        for (final a in item.assets) {
                          if (a.name.endsWith('.apk')) {
                            apkAsset = a;
                            break;
                          }
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.isCurrent ? const Color(0xFF2563EB) : borderColor,
                            width: item.isCurrent ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item.isCurrent
                                          ? const Color(0xFF2563EB)
                                          : (isDark ? const Color(0xFF2D333F) : const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'v${item.tag}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: item.isCurrent
                                            ? Colors.white
                                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (item.isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Установлена',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  if (item.publishedAt.isNotEmpty)
                                    Text(
                                      _formatDate(item.publishedAt),
                                      style: TextStyle(fontSize: 12, color: subColor),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...lines.map((line) {
                                if (line.startsWith('__HEADING__:')) {
                                  final h = line.replaceFirst('__HEADING__:', '');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                                    child: Text(
                                      h,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 6, right: 8),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: item.isCurrent
                                              ? const Color(0xFF2563EB)
                                              : subColor,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          line,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (apkAsset != null) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _launchUrl(apkAsset!.downloadUrl),
                                        icon: const Icon(Icons.download_rounded, size: 18),
                                        label: Text(
                                          apkAsset.formattedSize.isNotEmpty
                                              ? 'Скачать APK (${apkAsset.formattedSize})'
                                              : 'Скачать APK',
                                          style: const TextStyle(fontSize: 12.5),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'Смотреть релиз на GitHub',
                                      icon: const Icon(Icons.launch_rounded, size: 18),
                                      onPressed: () => _launchUrl(item.htmlUrl),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
