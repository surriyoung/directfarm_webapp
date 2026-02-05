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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

    bool _isSocialLoginEntry(Uri uri) {
    // directfarm 내부 카카오/네이버 진입
    final qp = uri.queryParameters;
    final isDirectfarm = uri.host == 'directfarm.co.kr';
    final provider = (qp['provider'] ?? '').toLowerCase();

    if (isDirectfarm && (provider == 'kakao' || provider == 'naver')) {
      return true;
    }

    // 실제 OAuth 도메인
    final host = uri.host.toLowerCase();
    if (host.contains('kauth.kakao.com')) return true;
    if (host.contains('accounts.kakao.com')) return true;
    if (host.contains('nid.naver.com')) return true;

    return false;
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        debugPrint('❌ launchUrl returned false: $uri');
      }
    } catch (e) {
      debugPrint('❌ external open failed: $uri / $e');

      // ✅ 카카오톡 스킴인데 앱이 없으면: 웹 로그인으로 우회(또는 스토어 이동)
      if (Platform.isAndroid && uri.scheme.toLowerCase() == 'kakaotalk') {
        // 1) 카카오 웹 로그인으로 fallback (가장 무난)
        final fallback = uri.queryParameters['url'];
        if (fallback != null && fallback.isNotEmpty) {
          await controller?.loadUrl(
            urlRequest: URLRequest(url: WebUri(Uri.decodeComponent(fallback))),
          );
          return;
        }

        // 2) 또는 Play Store로 유도하고 싶으면(선택)
        // await launchUrl(
        //   Uri.parse('market://details?id=com.kakao.talk'),
        //   mode: LaunchMode.externalApplication,
        // );
      }
    }
  }


  // ✅ 탭 순서: 홈(0) · 검색(1) · AI추천(2) · 장바구니(3) · 마이페이지(4)
  int _currentIndex = 0;
  int _lastWebIndex = 0;

  bool _inSettings = false;
  DateTime? _lastBackPressAt;
  bool _pageReady = false;

  static const _home = 'https://directfarm.co.kr/';
  static const _search = 'https://directfarm.co.kr/shop/search.php';
  static const _aiSuggest = 'https://directfarm.co.kr/shop/ai_suggest.php';
  static const _cart = 'https://directfarm.co.kr/shop/cart.php';
  static const _mypage = 'https://directfarm.co.kr/shop/mypage.php';

  bool _tabActive = true;

  // ✅ FAB 크기: (≤500) 50 / (≤650) 55 / 그 외 65
  double _fabSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width <= 500) return 50;
    if (width <= 650) return 55;
    return 65;
  }

  // ✅ 카카오 SVG (요청한 모양 그대로)
  String _kakaoSvg(double size) => '''
<svg width="$size" height="$size" viewBox="0 0 65 65" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect width="65" height="65" rx="32.5" fill="#FAE100"></rect>
  <path d="M32.4981 15.625C43.3731 15.625 52.1875 22.495 52.1875 30.9719C52.1875 39.4469 43.3731 46.3169 32.5 46.3169C31.4174 46.315 30.336 46.2461 29.2619 46.1106L20.9969 51.5163C20.0575 52.0131 19.7256 51.9588 20.1119 50.7419L21.7844 43.8456C16.3844 41.1081 12.8125 36.3644 12.8125 30.9719C12.8125 22.4969 21.625 15.625 32.5 15.625M43.5775 30.7375L46.3338 28.0675C46.4928 27.9023 46.5815 27.6819 46.5812 27.4526C46.581 27.2233 46.4917 27.0031 46.3323 26.8383C46.1728 26.6735 45.9557 26.577 45.7265 26.5692C45.4973 26.5613 45.2741 26.6427 45.1038 26.7963L41.4887 30.295V27.4037C41.4887 27.169 41.3955 26.9439 41.2295 26.778C41.0636 26.612 40.8385 26.5188 40.6037 26.5188C40.369 26.5188 40.1439 26.612 39.978 26.778C39.812 26.9439 39.7187 27.169 39.7187 27.4037V32.1981C39.6876 32.3351 39.6876 32.4774 39.7187 32.6144V35.3125C39.7187 35.5472 39.812 35.7723 39.978 35.9383C40.1439 36.1043 40.369 36.1975 40.6037 36.1975C40.8385 36.1975 41.0636 36.1043 41.2295 35.9383C41.3955 35.7723 41.4887 35.5472 41.4887 35.3125V32.7569L42.2894 31.9825L44.9669 35.7944C45.0337 35.8895 45.1187 35.9706 45.2169 36.033C45.315 36.0953 45.4245 36.1377 45.5391 36.1577C45.6537 36.1777 45.771 36.175 45.8845 36.1496C45.9981 36.1243 46.1055 36.0769 46.2006 36.01C46.2958 35.9431 46.3769 35.8582 46.4392 35.76C46.5015 35.6618 46.5439 35.5523 46.564 35.4378C46.584 35.3232 46.5812 35.2058 46.5559 35.0923C46.5306 34.9788 46.4831 34.8714 46.4163 34.7763L43.5775 30.7375ZM38.0312 34.345H35.2937V27.4319C35.2833 27.2045 35.1856 26.9898 35.0209 26.8326C34.8563 26.6753 34.6374 26.5876 34.4097 26.5876C34.182 26.5876 33.9631 26.6753 33.7985 26.8326C33.6338 26.9898 33.5361 27.2045 33.5256 27.4319V35.23C33.5256 35.7175 33.9194 36.115 34.4087 36.115H38.0312C38.266 36.115 38.4911 36.0218 38.657 35.8558C38.823 35.6898 38.9162 35.4647 38.9162 35.23C38.9162 34.9953 38.823 34.7702 38.657 34.6042C38.4911 34.4382 38.266 34.345 38.0312 34.345ZM27.0494 32.2994L28.3544 29.0969L29.5506 32.2975L27.0494 32.2994ZM31.78 33.2125L31.7838 33.1825C31.7831 32.9596 31.698 32.7452 31.5456 32.5825L29.5844 27.3325C29.5022 27.0823 29.3456 26.8632 29.1355 26.7044C28.9254 26.5456 28.6719 26.4546 28.4087 26.4438C28.1439 26.4436 27.8853 26.5236 27.6668 26.6732C27.4482 26.8228 27.2801 27.035 27.1844 27.2819L24.0681 34.9225C23.9794 35.1398 23.9806 35.3835 24.0715 35.5999C24.1624 35.8163 24.3355 35.9878 24.5528 36.0766C24.7701 36.1653 25.0138 36.1641 25.2302 36.0732C25.4467 35.9823 25.6181 35.8092 25.7069 35.5919L26.3294 34.0675H30.2106L30.7694 35.5675C30.8075 35.6796 30.8677 35.783 30.9465 35.8714C31.0253 35.9598 31.121 36.0315 31.228 36.0823C31.335 36.133 31.4511 36.1618 31.5694 36.1668C31.6877 36.1719 31.8058 36.1532 31.9168 36.1118C32.0277 36.0704 32.1292 36.0071 32.2153 35.9257C32.3013 35.8444 32.3702 35.7466 32.4178 35.6381C32.4653 35.5297 32.4906 35.4128 32.4922 35.2944C32.4938 35.1759 32.4716 35.0584 32.4269 34.9488L31.78 33.2125ZM25.5494 27.4413C25.5499 27.3251 25.5274 27.2099 25.4832 27.1024C25.439 26.995 25.374 26.8973 25.2919 26.815C25.2099 26.7328 25.1123 26.6676 25.0049 26.6231C24.8976 26.5787 24.7825 26.556 24.6663 26.5563H18.5819C18.3472 26.5563 18.1221 26.6495 17.9561 26.8155C17.7901 26.9814 17.6969 27.2065 17.6969 27.4413C17.6969 27.676 17.7901 27.9011 17.9561 28.067C18.1221 28.233 18.3472 28.3263 18.5819 28.3263H20.7569V35.3313C20.7569 35.566 20.8501 35.7911 21.0161 35.957C21.1821 36.123 21.4072 36.2163 21.6419 36.2163C21.8766 36.2163 22.1017 36.123 22.2677 35.957C22.4336 35.7911 22.5269 35.566 22.5269 35.3313V28.3263H24.6644C24.7807 28.3267 24.896 28.3042 25.0036 28.2599C25.1112 28.2156 25.209 28.1504 25.2913 28.0681C25.3735 27.9859 25.4387 27.8881 25.483 27.7805C25.5273 27.6729 25.5499 27.5576 25.5494 27.4413Z"
    fill="#371D1E"></path>
</svg>
''';

  void _syncNavByUrl(String? urlStr) {
    if (_inSettings) return;

    final matched = _matchTabIndex(urlStr ?? '');
    if (matched != null) {
      setState(() {
        _currentIndex = matched;
        _lastWebIndex = matched;
        _tabActive = true;
      });
    } else {
      setState(() => _tabActive = false);
    }
  }

  int? _matchTabIndex(String url) {
    if (url.isEmpty) return null;
    Uri? u;
    try {
      u = Uri.parse(url);
    } catch (_) {
      return null;
    }
    if (u.host != 'directfarm.co.kr') return null;

    switch (u.path) {
      case '/':
        return 0;
      case '/shop/search.php':
        return 1;
      case '/shop/ai_suggest.php':
        return 2;
      case '/shop/cart.php':
        return 3;
      case '/shop/mypage.php':
        return 4;
      default:
        return null;
    }
  }

  Future<void> _goTab(int index) async {
    if (_inSettings) setState(() => _inSettings = false);

    setState(() {
      _currentIndex = index;
      _lastWebIndex = index;
      _tabActive = true;
    });

    final targets = [_home, _search, _aiSuggest, _cart, _mypage];
    await controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(targets[index])),
    );
  }

  Future<bool> _onWillPop() async {
    if (_inSettings) {
      setState(() => _inSettings = false);
      return false;
    }

    final isMenuOpen = await controller?.evaluateJavascript(
      source:
          r'(function(){try{return window._isMenuOpen?window._isMenuOpen():false;}catch(e){return false;}})()',
    );

    if (isMenuOpen == true || isMenuOpen?.toString() == 'true') {
      await controller?.evaluateJavascript(
        source:
            r'(function(){try{if(window._closeMenu)window._closeMenu();}catch(e){} })()',
      );
      return false;
    }

    if (await controller?.canGoBack() ?? false) {
      await controller?.goBack();
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPressAt == null ||
        now.difference(_lastBackPressAt!) > const Duration(seconds: 2)) {
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
    bool _isMyPageUrl(String url) {
      try {
        final u = Uri.parse(url);
        return u.host == 'directfarm.co.kr' && u.path == '/shop/mypage.php';
      } catch (_) {
        return false;
      }
    }
    final bool showSettingsFab = _isMyPageUrl(_currentUrl);
    final baseTheme = Theme.of(context).navigationBarTheme;
    final disabledTheme = baseTheme.copyWith(
      indicatorColor: Colors.transparent,
      labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>(
          (_) => const TextStyle(color: Color(0xFF454545))),
      iconTheme: MaterialStateProperty.resolveWith<IconThemeData>(
          (_) => const IconThemeData(color: Color(0xFFA7A7A7))),
    );

    final size = _fabSize(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          bottom: true,
          child: IndexedStack(
            index: _inSettings ? 1 : 0,
            children: [
              InAppWebView(
                onReceivedError: (ctrl, req, err) {
                  debugPrint(
                      '❌ onReceivedError url=${req.url} type=${err.type} desc=${err.description}');
                },
                onReceivedHttpError: (ctrl, req, res) {
                  debugPrint('⚠️ onReceivedHttpError url=${req.url} status=${res.statusCode}');
                },

                initialUrlRequest: URLRequest(url: WebUri(_home)),
                initialSettings: InAppWebViewSettings(
                  limitsNavigationsToAppBoundDomains: true,
                  javaScriptEnabled: true,
                  transparentBackground: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,

                  useShouldOverrideUrlLoading: true,
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: true,

                  // ✅ UA 고정 (모바일 크롬/사파리처럼 보이게)
                  userAgent: Platform.isIOS
                      ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
                      : 'Mozilla/5.0 (Linux; Android 13; SM-G991N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',

                  // ✅ iOS 쿠키/세션 유지에 도움
                  sharedCookiesEnabled: true,

                  // ✅ (플러그인 버전에 따라 없을 수 있음: 빨간줄 뜨면 이 줄만 삭제)
                  thirdPartyCookiesEnabled: true,
                ),

                shouldOverrideUrlLoading: (webCtrl, action) async {
                  final webUri = action.request.url;
                  final raw = webUri?.toString() ?? '';

                  // ✅ 로그로 실제로 어떤 URL/스킴이 들어오는지 확인
                  debugPrint('➡️ shouldOverrideUrlLoading: $raw');

                  if (raw.isEmpty) return NavigationActionPolicy.ALLOW;

                  late final Uri uri;
                  try {
                    uri = Uri.parse(raw);
                  } catch (e) {
                    debugPrint('❌ Uri.parse failed: $raw / $e');
                    return NavigationActionPolicy.ALLOW;
                  }

                  final scheme = uri.scheme.toLowerCase();
                  final isHttp = scheme == 'http' || scheme == 'https';

                  // ✅ 요구사항: kakaokompassauth://, intent:// 나오면 외부 앱으로
                  final shouldExternal =
                      scheme == 'kakaokompassauth' ||
                      scheme == 'intent' ||
                      scheme == 'market' ||
                      scheme == 'itms-apps' ||
                      scheme == 'tel' ||
                      scheme == 'sms' ||
                      scheme == 'mailto' ||

                      // ✅ 카카오 계열 스킴 추가(실제 환경에서 자주 나옴)
                      scheme.startsWith('kakao') ||
                      scheme == 'kakaotalk' ||
                      scheme == 'kakaolink';

                  if (shouldExternal) {
                    debugPrint('🚀 external scheme: $scheme -> $raw');
                    await _openExternal(uri);
                    return NavigationActionPolicy.CANCEL;
                  }

                  // ✅ http/https는 웹뷰 내부 유지 (카카오 로그인 웹 플로우 유지)
                  if (isHttp) return NavigationActionPolicy.ALLOW;

                  // ✅ 그 외 커스텀 스킴도 외부 시도
                  debugPrint('🚀 external custom scheme: $scheme -> $raw');
                  await _openExternal(uri);
                  return NavigationActionPolicy.CANCEL;
                },

                onCreateWindow: (webCtrl, createWindowRequest) async {
                  final w = createWindowRequest.request.url;
                  final raw = w?.toString() ?? '';

                  debugPrint('🪟 onCreateWindow: $raw (null이면 JS window.open 케이스일 수 있음)');

                  // ✅ request.url이 null이면 여기서 뭘 할 수가 없음
                  // → 아래 3)에서 window.open을 location.href로 바꾸는 JS를 주입해서 해결
                  if (raw.isEmpty) return false;

                  late final Uri uri;
                  try {
                    uri = Uri.parse(raw);
                  } catch (_) {
                    return false;
                  }

                  final scheme = uri.scheme.toLowerCase();
                  final isHttp = scheme == 'http' || scheme == 'https';

                  final shouldExternal =
                      scheme == 'kakaokompassauth' ||
                      scheme == 'intent' ||
                      scheme == 'market' ||
                      scheme == 'itms-apps' ||
                      scheme == 'tel' ||
                      scheme == 'sms' ||
                      scheme == 'mailto' ||

                      // ✅ 카카오 계열 스킴 추가(실제 환경에서 자주 나옴)
                      scheme.startsWith('kakao') ||
                      scheme == 'kakaotalk' ||
                      scheme == 'kakaolink';

                  if (shouldExternal) {
                    await _openExternal(uri);
                    return false;
                  }

                  if (isHttp) {
                    await webCtrl.loadUrl(urlRequest: URLRequest(url: w));
                    return true;
                  }

                  await _openExternal(uri);
                  return false;
                },

                onWebViewCreated: (ctrl) async {
                  controller = ctrl;

                  // ✅ Android 3rd-party cookies 허용 (버전별 API 차이 안전 처리)
                  if (Platform.isAndroid) {
                    try {
                      final cm = CookieManager.instance();
                      await (cm as dynamic).setAcceptThirdPartyCookies(
                        controller: ctrl,
                        acceptThirdPartyCookies: true,
                      );
                    } catch (e) {
                      debugPrint('⚠️ setAcceptThirdPartyCookies not available: $e');
                    }
                  }
                },

                onLoadStart: (ctrl, url) {
                  final u = url?.toString() ?? _home;
                  setState(() => _currentUrl = u);
                  _syncNavByUrl(u);
                },
                onUpdateVisitedHistory: (ctrl, url, _) {
                  final u = url?.toString() ?? _home;
                  setState(() => _currentUrl = u);
                  _syncNavByUrl(u);
                },

                onLoadStop: (ctrl, url) async {
                  final u = url?.toString() ?? _home;
                  if (mounted) setState(() => _currentUrl = u);

                  await ctrl.evaluateJavascript(source: r'''
                    (function () {
                      try {
                        // ✅ window.open을 가로채서 팝업 대신 현재 창 이동으로 처리
                        if (!window._df_open_patched) {
                          window._df_open_patched = true;
                          const _open = window.open;
                          window.open = function(url, name, specs) {
                            try {
                              if (url) location.href = url;
                            } catch(e) {}
                            return null;
                          };
                        }
                      } catch(e) {}
                    })();
                  ''');
                  // footer 숨김 + bottom-nav 제거 + kakao-btn-wrap 제거(동적 생성 대비)
                  await ctrl.evaluateJavascript(source: r'''
                    (function(){
                      try {
                        var ft = document.getElementById('ft');
                        if (ft) ft.style.display = 'none';

                        function kill(){
                          try{
                            document.querySelectorAll('.kakao-btn-wrap').forEach(el => el.remove());
                          }catch(e){}
                        }

                        kill();

                        if (!window._dfBottomNavObserver) {
                          window._dfBottomNavObserver = new MutationObserver(function(){
                            kill();
                          });
                          window._dfBottomNavObserver.observe(document.body, { childList: true, subtree: true });
                        }
                      } catch(e) {}
                    })();
                  ''');

                  await ctrl.evaluateJavascript(source: r'''
                    (function(){
                      try{
                        window._isMenuOpen = function(){
                          try{
                            var cat = document.getElementById('category');
                            if(!cat) return false;
                            return getComputedStyle(cat).display !== 'none';
                          }catch(e){ return false; }
                        };

                        window._closeMenu = function(){
                          try{
                            if (window.jQuery && window.jQuery('#category .close_btn').length) {
                              window.jQuery('#category .close_btn').trigger('click');
                              return true;
                            }
                            document.documentElement.classList.remove('no-scroll');
                            document.body.classList.remove('no-scroll');
                            var cat = document.getElementById('category'); if(cat) cat.style.display='none';
                            var bg  = document.getElementById('category_all_bg'); if(bg) bg.style.display='none';
                            return true;
                          }catch(e){ return false; }
                        };
                      }catch(e){}
                    })();
                  ''');

                  _syncNavByUrl(u);
                  _pageReady = true;
                },
              ),
              SettingsScreen(
                onClearWebData: () async {
                  try {
                    await controller?.clearCache();
                    await CookieManager.instance().deleteAllCookies();
                    await WebStorageManager.instance().deleteAllData();
                  } catch (_) {}
                },
                onBack: () => setState(() => _inSettings = false),
                useScaffold: false,
              ),
            ],
          ),
        ),

        // ✅ 플로팅 버튼 2개(원형)
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 50), // ← 여기 숫자로 조절
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 카카오톡 버튼
              SizedBox(
                width: size,
                height: size,
                child: FloatingActionButton(
                  heroTag: 'kakao_fab',
                  shape: const CircleBorder(),
                  backgroundColor: Colors.transparent,
                  elevation: 6,
                  onPressed: () async {
                    await controller?.evaluateJavascript(
                      source: r"try{location.href='https://pf.kakao.com/_QXQyn/chat';}catch(e){}",
                    );
                  },
                  child: ClipOval(
                    child: SvgPicture.string(
                      _kakaoSvg(size),
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              // 설정 버튼
              if (showSettingsFab) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: size,
                  height: size,
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
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        // ✅ 하단 네비: 홈 검색 AI추천 장바구니 마이페이지
        // bottomNavigationBar: Theme(
        //   data: Theme.of(context).copyWith(
        //     navigationBarTheme: _tabActive ? baseTheme : disabledTheme,
        //   ),
        //   child: NavigationBar(
        //     selectedIndex: _currentIndex,
        //     onDestinationSelected: (i) async {
        //       if (!_pageReady) return;
        //       await _goTab(i);
        //     },
        //     labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        //     destinations: const [
        //       NavigationDestination(
        //         icon: Icon(Icons.home_outlined),
        //         selectedIcon: Icon(Icons.home),
        //         label: '홈',
        //       ),
        //       NavigationDestination(
        //         icon: Icon(Icons.search),
        //         label: '검색',
        //       ),
        //       NavigationDestination(
        //         icon: Icon(Icons.auto_awesome_outlined),
        //         selectedIcon: Icon(Icons.auto_awesome),
        //         label: 'AI추천',
        //       ),
        //       NavigationDestination(
        //         icon: Icon(Icons.shopping_bag_outlined),
        //         selectedIcon: Icon(Icons.shopping_bag),
        //         label: '장바구니',
        //       ),
        //       NavigationDestination(
        //         icon: Icon(Icons.person_outline),
        //         selectedIcon: Icon(Icons.person),
        //         label: '마이페이지',
        //       ),
        //     ],
        //   ),
        // ),
      ),
    );
  }
}
