import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final Future<void> Function() onClearWebData;

  const SettingsScreen({
    super.key,
    required this.onClearWebData, required bool useScaffold,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정'),),
      body: ListView(
        children: [
          const _SectionHeader('일반'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('앱 정보'),
            subtitle: const Text('버전, 라이선스'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '다이렉트팜',
                applicationVersion: '1.0.0',
                applicationIcon: Image.asset(
                  "assets/logo/icon.png",
                  width: 48,
                  height: 48,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('웹 데이터 삭제'),
            subtitle: const Text('캐시/쿠키/스토리지 정리'),
            onTap: () async {
              await onClearWebData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('웹 데이터가 삭제되었습니다.')),
                );
              }
            },
          ),
          const Divider(height: 24),
          const _SectionHeader('고객센터'),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('문의하기'),
            subtitle: const Text('카카오톡 연결 예정'),
            onTap: () {
              // TODO: 추후 카카오톡 채널 연결
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('문의하기는 곧 연결됩니다.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
