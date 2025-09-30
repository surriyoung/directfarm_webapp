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

  int _currentIndex = 0;
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
        _currentIndex = matched;
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
      case '/':                return 0;
      case '/shop/search.php': return 1;
      case '/shop/cart.php':   return 2;
      case '/shop/mypage.php': return 3;
      default:                 return null;
    }
  }

  Future<void> _goTab(int index) async {
    setState(() { _currentIndex = index; _tabActive = true; });
    final targets = [_home, _search, _cart, _mypage];
    await controller?.loadUrl(urlRequest: URLRequest(url: WebUri(targets[index])));
  }

  Future<bool> _onWillPop() async {
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
          child: InAppWebView(
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
        ),
        floatingActionButton: (_onMyPage && _tabActive)
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFFFFFFFF), // 버튼 배경 흰색
                  shape: const CircleBorder(),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          onClearWebData: () async {
                            try {
                              await controller?.clearCache();
                              await CookieManager.instance().deleteAllCookies();
                              await WebStorageManager.instance().deleteAllData();
                            } catch (_) {}
                          },
                        ),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.settings,
                    color: Color(0xFF005504), // 아이콘 색상
                  ),
                ),
              )
            : null,
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: _tabActive ? baseTheme : disabledTheme,
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) { if (_pageReady) _goTab(i); },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
              NavigationDestination(icon: Icon(Icons.search), label: '검색'),
              NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: '장바구니'),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '마이페이지'),
            ],
          ),
        ),
      ),
    );
  }
}