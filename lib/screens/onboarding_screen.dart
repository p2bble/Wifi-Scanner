import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _PageData(
      icon: Icons.health_and_safety,
      color: Color(0xFF1976D2),
      title: 'WiFi 환경, 한눈에 파악',
      description: '버튼 하나로 신호·품질·속도를\n자동 측정해 A~F 등급으로 알려드려요.',
    ),
    _PageData(
      icon: Icons.wifi_find,
      color: Color(0xFF388E3C),
      title: '주변 AP & 채널 분석',
      description: '주변 AP 전체를 스캔하고\n채널 혼잡도를 차트로 시각화해요.',
    ),
    _PageData(
      icon: Icons.route,
      color: Color(0xFFF57C00),
      title: '음영 구간 자동 감지',
      description: '이동하면서 신호 변화를 실시간 기록하고\n약한 구간을 자동으로 찾아드려요.',
    ),
    _PageData(
      icon: Icons.summarize,
      color: Color(0xFF7B1FA2),
      title: '현장 리포트 1탭 공유',
      description: '측정 결과를 보기 좋은 리포트로 정리해\n카카오톡·슬랙에 바로 공유하세요.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 건너뛰기
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  onPressed: isLast ? null : _finish,
                  child: Text(
                    '건너뛰기',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              ),
            ),

            // 페이지 뷰
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _PageContent(page: _pages[i]),
              ),
            ),

            // 도트 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final isActive = _currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? primaryColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // 다음 / 시작하기 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isLast ? '시작하기' : '다음',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _PageData page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: page.color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 76, color: page.color),
          ),
          const SizedBox(height: 52),
          Text(
            page.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _PageData({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
