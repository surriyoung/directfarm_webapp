import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildDirectFarmTheme(),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const WebViewApp(),
    ),
  );
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});
  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  String _currentUrl = 'https://directfarm.co.kr/';
  InAppWebViewController? controller;
  bool _inSettings = false;
  DateTime? _lastBackPressAt;
  bool _pageReady = false;

  static const _home = 'https://directfarm.co.kr/';

  // 📌 데이터 초기화 함수 (로그아웃 시 세션 정리)
  Future<void> _clearWebViewData() async {
    try {
      await CookieManager.instance().deleteAllCookies();
      await WebStorageManager.instance().deleteAllData();
      await controller?.clearCache();
      debugPrint("🧹 캐시 및 쿠키 초기화 완료");
    } catch (e) {
      debugPrint("❌ 초기화 에러: $e");
    }
  }

  // 📌 외부 앱 실행 (전화, 카카오톡 등)
  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("❌ 외부 앱 실행 실패: $e");
    }
  }

  double _fabSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width <= 500) return 50;
    if (width <= 650) return 55;
    return 65;
  }

  @override
  Widget build(BuildContext context) {
    final size = _fabSize(context);
    final bool showSettingsFab = _currentUrl.contains('/shop/mypage.php');

    return PopScope(
      canPop: false, // 시스템 백버튼 기본 동작 제어
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // 1. 설정 화면 닫기
        if (_inSettings) {
          setState(() => _inSettings = false);
          return;
        }

        // 2. 웹뷰 내부 메뉴 닫기 (JS 호출)
        final isMenuOpen = await controller?.evaluateJavascript(
          source: r'(function(){try{return window._isMenuOpen?window._isMenuOpen():false;}catch(e){return false;}})()',
        );
        if (isMenuOpen == true) {
          await controller?.evaluateJavascript(source: r'if(window._closeMenu)window._closeMenu();');
          return;
        }

        // 3. 웹뷰 뒤로가기
        if (await controller?.canGoBack() ?? false) {
          await controller?.goBack();
          return;
        }

        // 4. 더블 탭 종료 체크
        final now = DateTime.now();
        if (_lastBackPressAt == null || now.difference(_lastBackPressAt!) > const Duration(seconds: 2)) {
          _lastBackPressAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('한 번 더 누르면 종료됩니다.'), duration: Duration(seconds: 2)),
          );
          return;
        }

        // 5. 최종 앱 종료
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: true,
          child: IndexedStack(
            index: _inSettings ? 1 : 0,
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_home)),
                initialSettings: InAppWebViewSettings(
                  sharedCookiesEnabled: true,
                  incognito: false,
                  cacheEnabled: true,
                  limitsNavigationsToAppBoundDomains: false,
                  javaScriptEnabled: true,
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  useShouldOverrideUrlLoading: true,
                  // 📌 [중요] User-Agent 설정: 끝에 ' DirectFarmApp' 추가
                  userAgent: Platform.isIOS
                      ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
                      : 'Mozilla/5.0 (Linux; Android 13; SM-G991N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                ),

                // 📌 소셜 로그인 팝업 대응 (Referer 유지)
                onCreateWindow: (webCtrl, createWindowRequest) async {
                  final request = createWindowRequest.request;
                  final url = request.url;
                  if (url == null) return false;

                  if (url.scheme != 'http' && url.scheme != 'https') {
                    await _openExternal(url);
                    return false;
                  }

                  Map<String, String> headers = Map<String, String>.from(request.headers ?? {});
                  headers['Referer'] = _currentUrl; 

                  await webCtrl.loadUrl(
                    urlRequest: URLRequest(
                      url: url,
                      method: request.method,
                      body: request.body,
                      headers: headers,
                    ),
                  );
                  return true;
                },

                shouldOverrideUrlLoading: (webCtrl, action) async {
                  final uri = action.request.url;
                  if (uri == null) return NavigationActionPolicy.ALLOW;

                  final scheme = uri.scheme.toLowerCase();
                  if (scheme != 'http' && scheme != 'https') {
                    await _openExternal(uri);
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },

                onWebViewCreated: (ctrl) => controller = ctrl,
                
                onLoadStart: (ctrl, url) async {
                  final urlStr = url?.toString() ?? "";
                  setState(() => _currentUrl = urlStr);

                  // 로그아웃 주소 진입 시 캐시 청소
                  if (urlStr.contains("logout")) {
                    await _clearWebViewData();
                  }
                },

                onLoadStop: (ctrl, url) async {
                  setState(() => _currentUrl = url?.toString() ?? _home);
                  _pageReady = true;

                  // 📌 푸터 제거 (ID: ft)
                  await ctrl.evaluateJavascript(source: r'''
                    (function(){
                      try {
                        var ft = document.getElementById('ft');
                        if (ft) ft.style.display = 'none';
                      } catch(e) {}
                    })();
                  ''');
                },
              ),
              SettingsScreen(
                onClearWebData: () async {
                  await _clearWebViewData();
                  setState(() => _inSettings = false);
                },
                onBack: () => setState(() => _inSettings = false),
                useScaffold: false,
              ),
            ],
          ),
        ),

        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showSettingsFab) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: size, height: size,
                  child: FloatingActionButton(
                    heroTag: 'settings_fab',
                    shape: const CircleBorder(),
                    onPressed: () => setState(() => _inSettings = true),
                    child: Icon(Icons.settings, size: size * 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}