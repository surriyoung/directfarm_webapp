import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  final Future<void> Function() onClearWebData;

  const SettingsScreen({
    super.key,
    required this.onClearWebData,
    required bool useScaffold, // 기존 파라미터 유지
  });

  /// 앱 내부 WebView로 URL 열기
  Future<void> _openUrlInApp(String url) async {
    final uri = Uri.parse(url);
    final success = await launchUrl(
      uri,
      mode: LaunchMode.inAppWebView, // ✅ 앱 내부에서 열기
      webViewConfiguration: const WebViewConfiguration(
        enableJavaScript: true,
      ),
    );

    if (!success) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          /// =====================
          /// 일반
          /// =====================
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
                  'assets/logo/icon.png',
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

          /// =====================
          /// 약관 및 정책
          /// =====================
          const _SectionHeader('약관 및 정책'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('이용약관'),
            onTap: () {
              _openUrlInApp(
                'https://directfarm.co.kr/bbs/content.php?co_id=provision',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('개인정보처리방침'),
            onTap: () {
              _openUrlInApp(
                'https://directfarm.co.kr/bbs/content.php?co_id=privacy',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('FAQ'),
            onTap: () {
              _openUrlInApp('https://directfarm.co.kr/bbs/faq.php');
            },
          ),

          const Divider(height: 24),

          /// =====================
          /// 고객센터
          /// =====================
          const _SectionHeader('고객센터'),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('문의하기'),
            subtitle: const Text('카카오톡 채널 연결'),
            onTap: () {
              _openUrlInApp('https://pf.kakao.com/_QXQyn/chat');
              // 예시: https://pf.kakao.com/_xjKAbK
            },
          ),

          /// =====================
          /// 사업자 정보(푸터)
          /// =====================
          const Divider(height: 32),
          const _AppFooter(),
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

class _AppFooter extends StatelessWidget {
  const _AppFooter();

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Colors.grey[600], height: 1.5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('주식회사 다이렉트팜', style: textStyle),
          const SizedBox(height: 6),
          Text('대표자 박정우 | 사업자등록번호 454-87-03277', style: textStyle),
          Text('통신판매업신고번호 제 2025-경북영천-0244호', style: textStyle),
          const SizedBox(height: 6),
          Text('문의: directfarm@directfarm.co.kr', style: textStyle),
          const SizedBox(height: 12),
          Text('© 2025 DirectFarm. All Rights Reserved.', style: textStyle),
        ],
      ),
    );
  }
}
