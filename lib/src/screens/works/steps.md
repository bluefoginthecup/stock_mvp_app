# 📊 StockApp MVP 개발 로드맵

> **목표:** 재고·주문·작업·발주·입출고를 하나의 데이터 흐름으로 통합  
> **베이스:** Flutter + Provider + InMemoryRepo / SQLite 전환 가능 구조

---

## ⚙️ 전체 개발 단계 (코딩 순서표)

| 단계 | 목표 | 구체 작업(코드) | 파일/폴더 | 완료 기준(DoD) |
|------|------|----------------|-------------|----------------|
| **0** | 베이스라인 고정 | `pubspec.yaml` 정리 (`version`, deps). `main.dart`를 **InMemoryRepo + RepoView 패턴**으로 구성. import 오류 정리. | `pubspec.yaml`, `lib/main.dart`, `lib/src/repos/repo_views.dart` | `flutter run` 무오류, 대시보드·재고·주문·입출고 화면 진입 OK |
| **1** | 인터페이스 추상화 확정 | `repo_views.dart`(비-Listenable 위임 래퍼) 추가·확인. 화면은 `read<ItemRepo>()` 사용 + `watch<InMemoryRepo>()`로 리빌드. | `lib/src/repos/repo_views.dart`, 각 `screens/*.dart` | “Provider Listenable 에러” 재발 없음 |
| **2** | 도메인 모델 보강 | **Work(작업)**, **Purchase(발주)** 모델·인터페이스 정의. InMemoryRepo에 임시 구현 추가. | `lib/src/models/work.dart`, `purchase.dart`, `lib/src/repos/repo_interfaces.dart`, `inmem_repo.dart` | mock 생성/조회 메서드 동작 |
| **3** | 주문 저장 → 부족분 계산 | `ShortageService` 구현: 주문 저장 시 각 라인별 `(재고 - 필요수량)` 계산 → 부족분만큼 **Work/Purchase** 제안 생성. | `lib/src/services/shortage_service.dart`, `order_form_screen.dart` | 주문 저장 후 콘솔/스낵바에 제안 수 확인 |
| **4** | 작업/발주 목록·상세 | **Work/발주 리스트 & 상세 화면**(카드·상태 버튼). 상태: `planned → inProgress → done`. | `lib/src/screens/work/work_list_screen.dart`, `work_detail_screen.dart`, `purchase/*` | 상태 전환 동작 |
| **5** | Txn 참조 연결 | 상태 전환 시 자동 입·출고: `Work.done` → **자재 OUT + 결과물 IN**, `Purchase.done` → **자재 IN**. `Txn.refType/refId` 채움. | `inmem_repo.dart`, `models/txn.dart` | Txn 리스트에서 참조 표시·수량 일치 |
| **6** | 재고·검색 고도화 | 폴더/서브폴더 필터 UI, 이름/코드/폴더 동시 검색, 임계치 하이라이트. | `stock_list_screen.dart`, `stock_new_item_sheet.dart` | 키워드+폴더 필터 동작 |
| **7** | BOM 편집(최소형) | **BOM 추가/삭제 폼**(부모=반/완제품, 자재=원/부자재, `qtyPer`). 부족분 계산 시 BOM 참고(옵셔널). | `models/bom.dart`, `screens/bom/bom_editor.dart`, `inmem_repo.dart` | BOM 추가·조회·삭제 가능 |
| **8** | Txn 레저 & 익스포트 | Txn 필터(기간/품목/타입), CSV 내보내기. | `txn_list_screen.dart`, `utils/csv.dart` | 필터·CSV 동작 |
| **9** | 대시보드 보강 | “임계치 이하 N건”, “미완 작업/발주 수”, “금일 입·출고 수” 카드 추가. | `dashboard_screen.dart`, `inmem_repo.dart` | 카드 수치 변화 즉시 반영 |
| **10** | SQLite 전환 준비 | `SqliteRepo` 구현: `items/orders/order_lines/bom/txns` CRUD. Mapper 작성. | `sqlite_repo.dart`, `assets/sql/schema.sql` | SqliteRepo로 스위치 시 정상 동작 |
| **11** | 리포지토리 스위치 | `main.dart` Provider에서 RepoView의 `inner`를 `SqliteRepo()`로 교체(한 줄). | `main.dart` | 화면 코드 변경 없이 동작 |
| **12** | 백업/복원(선택) | Google Drive에 SQLite 파일 백업/복원. | `services/backup_service.dart` | 수동 백업·복원 1회 성공 |
| **13** | 테스트/품질 | 부족분/상태전환/txn 생성 테스트. | `test/*.dart` | `flutter test` 통과 |
| **14** | 릴리즈 준비 | iOS 번들/버전, Android 패키지명, 아이콘/스플래시. | `pubspec.yaml`, `ios/`, `android/` | 실기기 빌드 OK |

---

## 🧱 화면별 구현 체크리스트

| 화면 | 주요 기능 | 완료 조건 |
|------|------------|------------|
| **재고(Stock)** | 목록·검색·필터, 새 품목·수정, 수량 조정(입·출고) | 모든 동작 정상 |
| **주문(Order)** | 목록·상세·편집, 저장 시 **부족분 계산** | 저장 시 자동 제안 생성 |
| **작업(Work)** | 목록·상세, 상태 전환 시 Txn 생성 | 입·출고 Txn 생성됨 |
| **발주(Purchase)** | 목록·상세, 상태 전환 시 Txn 생성 | 입고 Txn 생성됨 |
| **BOM** | 부모-자재 매핑 편집 | 추가·삭제·조회 정상 |
| **Txn** | 목록·필터·CSV | 필터 동작, CSV 생성 |
| **대시보드** | 임계치·미완 수·금일 Txn 카드 | 수치 정확 반영 |
| **리포지토리** | InMemoryRepo ↔ SqliteRepo 교체 | 코드 수정 없이 스위치 가능 |

---

## 🗂 새 파일/폴더 가이드

| 파일 | 역할 |
|------|------|
| `lib/src/services/shortage_service.dart` | 주문 저장 시 부족분 계산 & 제안 생성 |
| `lib/src/models/work.dart`, `purchase.dart` | 작업·발주 모델 (`id`, `status`, `lines`, `note`) |
| `lib/src/screens/work/*`, `purchase/*` | 리스트/상세/상태 버튼 |
| `lib/src/screens/bom/bom_editor.dart` | 간단 BOM 편집 화면 |
| `lib/src/utils/csv.dart` | `List<Txn>` → CSV 변환 유틸 |

---

## 🧩 코딩 규칙 요약

- **데이터 호출:** `final repo = context.read<ItemRepo>();`
- **화면 리빌드 트리거:** `context.watch<InMemoryRepo>();`
- **상태 전환 → Txn 생성**은 Repo/Service 쪽에서 처리 (화면은 얇게)
- **SQLite 전환**은 Provider의 `inner`만 바꾸면 완료

---

## 🚀 향후 확장 아이디어

- 생산 단가/자재 원가 자동 계산
- 그래프/대시보드 통계
- Google Drive / Firebase Sync 옵션
- 사용자 다계정(Workshop 공유)
- 모바일 → Web 빌드 통합

---

**✅ 권장 파일명:** `PROJECT_PLAN.md`  
**✅ 유지 방법:** 단계 완료 시 체크박스 `[x]` 추가  
**✅ 주기:** 단계별 커밋 & 태그(`v0.x`, `v1.0`)로 버전 관리

