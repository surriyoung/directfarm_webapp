import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';

import 'screens/settings_screen.dart';

void main() {
  runApp(
    MaterialApp(
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
  InAppWebViewController? controller;

  // 탭 순서: 검색(0) · 장바구니(1) · 홈(2) · 마이페이지(3) · 설정(4)
  int _currentIndex = 2; // 기본 '홈'
  int _lastWebIndex = 2; // 마지막으로 본 웹 탭(0~3)
  DateTime? _lastBackPressAt;
  bool _pageReady = false;

  static const _home   = 'https://directfarm.co.kr/';
  static const _search = 'https://directfarm.co.kr/shop/search.php';
  static const _cart   = 'https://directfarm.co.kr/shop/cart.php';
  static const _mypage = 'https://directfarm.co.kr/shop/mypage.php';

  bool _tabActive = true;
  bool _onMyPage = false;

  void _syncNavByUrl(String? urlStr) {
    final matched = _matchTabIndex(urlStr ?? '');
    final isMy = _isMyPage(urlStr ?? '');
    if (matched != null) {
      setState(() {
        // 설정 탭(4)에서 웹뷰가 로드되더라도 현재 선택은 유지
        if (_currentIndex != 4) _currentIndex = matched;
        _lastWebIndex = matched; // 마지막 웹 탭 기록
        _tabActive = true;
        _onMyPage = isMy;
      });
    } else {
      setState(() {
        _tabActive = false;
        _onMyPage = isMy;
      });
    }
  }

  bool _isMyPage(String url) {
    if (url.isEmpty) return false;
    try {
      final u = Uri.parse(url);
      return u.host == 'directfarm.co.kr' && u.path == '/shop/mypage.php';
    } catch (_) {
      return false;
    }
  }

  int? _matchTabIndex(String url) {
    if (url.isEmpty) return null;
    Uri? u;
    try { u = Uri.parse(url); } catch (_) { return null; }
    if (u.host != 'directfarm.co.kr') return null;
    switch (u.path) {
      case '/shop/search.php': return 0;
      case '/shop/cart.php':   return 1;
      case '/':                return 2;
      case '/shop/mypage.php': return 3;
      default:                 return null;
    }
  }

  Future<void> _goTab(int index) async {
    // 설정 탭은 같은 화면 내 전환만
    if (index == 4) {
      setState(() {
        _currentIndex = 4;
        _tabActive = true;
      });
      return;
    }

    // 웹 탭 이동(0~3)
    setState(() {
      _currentIndex = index;
      _lastWebIndex = index;
      _tabActive = true;
    });
    final targets = [_search, _cart, _home, _mypage];
    await controller?.loadUrl(urlRequest: URLRequest(url: WebUri(targets[index])));
  }

  Future<bool> _onWillPop() async {
    // 설정 탭에서 뒤로가기 → 마지막 웹 탭으로 복귀
    if (_currentIndex == 4) {
      setState(() => _currentIndex = _lastWebIndex);
      return false;
    }

    final isMenuOpen = await controller?.evaluateJavascript(
      source: r'(function(){try{return window._isMenuOpen?window._isMenuOpen():false;}catch(e){return false;}})()',
    );

    if (isMenuOpen == true || isMenuOpen?.toString() == 'true') {
      await controller?.evaluateJavascript(
        source: r'(function(){try{if(window._closeMenu)window._closeMenu();}catch(e){} })()',
      );
      return false;
    }

    if (await controller?.canGoBack() ?? false) {
      await controller?.goBack();
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressAt == null || now.difference(_lastBackPressAt!) > const Duration(seconds: 2)) {
      _lastBackPressAt = now;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('한 번 더 누르면 종료됩니다.')),
        );
      }
      return false;
    }

    await SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context).navigationBarTheme;
    final disabledTheme = baseTheme.copyWith(
      indicatorColor: Colors.transparent,
      labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>((_) => const TextStyle(color: Color(0xFF454545))),
      iconTheme: MaterialStateProperty.resolveWith<IconThemeData>((_) => const IconThemeData(color: Color(0xFFA7A7A7))),
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentIndex == 4 ? 1 : 0, // 0=웹뷰, 1=설정
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_home)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  transparentBackground: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                ),
                onWebViewCreated: (ctrl) async { controller = ctrl; },
                onLoadStart: (ctrl, url) => _syncNavByUrl(url?.toString()),
                onUpdateVisitedHistory: (ctrl, url, _) => _syncNavByUrl(url?.toString()),
                onLoadStop: (ctrl, url) async {
                  await ctrl.evaluateJavascript(source: '''
                    (function(){ var el=document.getElementById('ft'); if(el){el.style.display='none';} })();
                  ''');
                  await ctrl.evaluateJavascript(source: r'''
                    (function(){
                      try{
                        window._isMenuOpen = function(){
                          try{ var cat=document.getElementById('category'); if(!cat) return false; return getComputedStyle(cat).display!=='none'; }catch(e){ return false; }
                        };
                        window._closeMenu = function(){
                          try{
                            if (window.jQuery && window.jQuery('#category .close_btn').length) {
                              window.jQuery('#category .close_btn').trigger('click'); return true;
                            }
                            document.documentElement.classList.remove('no-scroll');
                            document.body.classList.remove('no-scroll');
                            var cat=document.getElementById('category'); if(cat) cat.style.display='none';
                            var bg=document.getElementById('category_all_bg'); if(bg) bg.style.display='none';
                            return true;
                          }catch(e){ return false; }
                        };
                      }catch(e){}
                    })();
                  ''');
                  _syncNavByUrl(url?.toString());
                  _pageReady = true;
                },
              ),

              // 설정 화면(임베드 모드) — 하단 네비 유지
              SettingsScreen(
                onClearWebData: () async {
                  try {
                    await controller?.clearCache();
                    await CookieManager.instance().deleteAllCookies();
                    await WebStorageManager.instance().deleteAllData();
                  } catch (_) {}
                },
                // 임베드 모드로 사용 (단독 화면으로 쓰고 싶으면 useScaffold: true)
                useScaffold: false,
              ),
            ],
          ),
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: _tabActive ? baseTheme : disabledTheme,
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) async {
              // 설정 탭은 URL 로드 없이 화면 전환만
              if (i == 4) {
                setState(() => _currentIndex = 4);
                return;
              }

              if (!_pageReady) return; // 초기 로딩 보호
              await _goTab(i);
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search), label: '검색'),
              NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: '장바구니'),
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '마이페이지'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '설정'),
            ],
          ),
        ),
      ),
    );
  }
}
