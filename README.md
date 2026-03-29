# 📡 WiFi 진단기

> 현장 개발자를 위한 가볍고 직관적인 WiFi 환경 분석 도구

네트워크를 잘 모르는 개발자가 현장에 갔을 때, 지금 이 자리의 WiFi 환경이 어떤 상태인지 빠르게 파악하고 팀에 공유할 수 있도록 만들어진 앱입니다.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20PWA-green)](https://github.com/p2bble/Wifi-Scanner)
[![Version](https://img.shields.io/badge/Version-1.2.0-orange)](https://github.com/p2bble/Wifi-Scanner/releases)

---

## 주요 기능

### 탭 1 — 연결 정보
- 현재 연결된 SSID, BSSID, 신호 세기(dBm), 주파수 대역, 채널 번호
- IP 주소 / 게이트웨이
- 게이트웨이 Ping, 인터넷 Ping (Google generate_204 기반)
- 신호 등급 라벨: 매우 좋음 / 좋음 / 보통 / 나쁨 / 매우 나쁨

### 탭 2 — 주변 AP
- 주변 AP 전체 목록 (신호 강도 순 정렬)
- SSID / 신호 세기 / 주파수 대역 / 채널 / 보안 여부
- 현재 연결된 AP 배지 표시
- 숨겨진 네트워크 표시

### 탭 3 — 채널 현황
- 2.4GHz / 5GHz 채널별 AP 수 Bar Chart
- 채널 3개 이상 → 빨간 막대 + ⚠️ 혼잡 표시
- 채널별 AP 이름 목록

### 탭 4 — 음영 추적
- 이동하면서 2초 간격 RSSI 자동 기록
- 실시간 꺾은선 그래프 (−75dBm 기준선 점선)
- 음영 구간(−75dBm 이하) 자동 감지 및 경고
- 위치 메모 첨부 기능
- Min / Max / 평균 RSSI 통계

### 탭 5 — 리포트
- 측정 환경 선택: 🏠 가정 / 🏢 사무실 / 🏭 공장·현장
- 환경별 신호 판정 멘트 (기준이 다름)
- 측정 위치 텍스트 입력
- 전체 요약 리포트 생성 + 카카오톡/슬랙 등 1탭 공유

---

## 리포트 샘플

```
📡 현장 WiFi 환경 리포트
━━━━━━━━━━━━━━━━━━━━━
📅 2026-03-27 22:36
📍 측정 위치: 1층 로비
🏷️ 측정 환경: 🏭 공장/현장

[연결 정보]
SSID: CLOBOT-5G
신호: -52dBm (좋음) 🟡
주파수: 5GHz / Ch36
보안: 🔒 암호화됨
판정: ✅ 양호 (장비 통신 안정)

[채널 혼잡도]
5GHz Ch48: 3개 AP ⚠️ 혼잡

[음영 추적 결과]
총 30회 측정 | Min: -78dBm | Max: -52dBm | 평균: -61dBm
판정: ⚠️ 음영 3회 — AMR 경로 재설계 또는 AP 증설 필요

[종합 판정]
❌ 채널 혼잡 — 로봇/설비 통신 간섭 위험, 전파 조사 필요
━━━━━━━━━━━━━━━━━━━━━
📱 WiFi 진단기로 측정
```

---

## 기술 스택

| 구분 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.41.6 (Dart 3.11.4) |
| 플랫폼 | Android (주), Web |
| WiFi 스캔 | wifi_scan ^0.4.1 |
| 네트워크 정보 | network_info_plus ^6.0.0 |
| 권한 관리 | permission_handler ^11.0.0 |
| 차트 | fl_chart ^0.68.0 |
| HTTP | http ^1.6.0 |
| 공유 | share_plus ^10.0.0 |
| 날짜 포맷 | intl ^0.19.0 |

---

## 프로젝트 구조

```
lib/
├── main.dart                  # 앱 진입점, 5탭 BottomNavigationBar
├── models/
│   ├── wifi_data.dart         # ApInfo, ConnectedNetworkInfo
│   └── signal_record.dart     # 음영 추적 데이터 모델
├── services/
│   └── wifi_service.dart      # WiFi 스캔, 연결 정보, Ping
└── screens/
    ├── connected_tab.dart     # 탭1: 현재 연결 정보
    ├── ap_list_tab.dart       # 탭2: 주변 AP 목록
    ├── channel_tab.dart       # 탭3: 채널 혼잡도
    ├── shadow_tab.dart        # 탭4: 음영 추적
    └── report_tab.dart        # 탭5: 리포트 생성 및 공유
```

---

## 환경 설정 및 실행

### 요구사항
- Flutter 3.x 이상
- Android SDK (minSdkVersion 21)
- Android 기기 (WiFi 스캔은 Android 전용)

### 실행

```bash
flutter pub get
flutter run
```

### Android 권한 (자동 요청)
- `ACCESS_FINE_LOCATION` — WiFi 스캔 필수 (Android 정책)
- `ACCESS_WIFI_STATE` / `CHANGE_WIFI_STATE`
- `NEARBY_WIFI_DEVICES` — Android 13+

---

## 플랫폼별 제약

| 플랫폼 | AP 스캔 | 채널/RSSI | 비고 |
|--------|:-------:|:---------:|------|
| Android | ✅ | ✅ | 위치 권한 필요 |
| iOS | ❌ | 연결된 것만 | Apple 정책으로 AP 목록 스캔 불가 |
| Web (PWA) | ❌ | ❌ | 브라우저 WiFi API 없음, 연결정보/리포트 탭은 일부 동작 |

---

## 🌐 Web PWA 배포 (iPhone / 브라우저 지원)

Apple Developer 계정 없이 iPhone 사용자도 웹 브라우저로 앱을 사용할 수 있도록 **Progressive Web App(PWA)** 로 배포되어 있습니다.

### 접속 방법

**GitHub Pages URL (배포 예정):**
```
https://p2bble.github.io/wifi_scout/
```

### iPhone에서 홈 화면 추가 방법
1. Safari로 위 URL 접속
2. 하단 공유 버튼(□↑) 탭
3. "홈 화면에 추가" 선택
4. 앱 아이콘이 홈 화면에 추가됨 → 앱처럼 실행

> **참고:** iOS 정책상 WiFi 스캔(AP 목록, 채널 현황, 음영 추적)은 동작하지 않습니다.
> 브라우저에서 접속 시 각 탭에 "지원하지 않는 환경" 안내가 표시됩니다.

### 로컬 테스트
```bash
flutter build web --release
python -m http.server 8080 --directory build/web
# http://localhost:8080 접속
```

### GitHub Pages 배포
```bash
flutter build web --release --base-href "/wifi_scout/"
# build/web/ 내용을 gh-pages 브랜치에 push
```

---

## 버전 히스토리

### v1.2.0 (2026-03-29)
- **Web PWA 지원 추가**: iPhone / 브라우저 사용자를 위한 Progressive Web App 배포
- 웹 접속 시 크래시 방지 처리 (`!kIsWeb` 가드 — 권한 요청, WiFi 스캔 호출)
- 웹 미지원 탭(AP 목록 / 채널 현황 / 음영 추적)에 안내 UI 추가
- `web/manifest.json` — 앱 이름/색상/설명 한국어 업데이트
- `web/index.html` — iOS PWA 메타태그(apple-mobile-web-app) 완성
- GitHub Pages 배포 구성 (`--base-href "/wifi_scout/"`)

### v1.1.0 (2026-03-28)
- WiFi 표준 표시 추가: 802.11ac / WiFi 6(ax) / WiFi 7(be) 구분 (연결 정보, 주변 AP 탭)
- 최적 채널 추천 카드 추가: 2.4GHz (1/6/11 기준), 5GHz (인접 채널 간섭 고려)
- CSV 내보내기: AP 스캔 결과를 CSV 파일로 공유

### v1.0.0 (2026-03-27)
- 최초 릴리즈
- 5탭 구조: 연결 정보 / 주변 AP / 채널 현황 / 음영 추적 / 리포트
- 환경별(가정/사무실/공장) 판정 멘트
- 음영 추적 및 RSSI 시계열 그래프
- 리포트 공유 기능

---

## 개발자

**p2bble** · [GitHub](https://github.com/p2bble)

> AMR 네트워크 모니터링 경험을 바탕으로,
> 현장에서 실제로 필요한 기능만 담았습니다.
