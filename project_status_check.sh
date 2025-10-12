#!/usr/bin/env bash
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass(){ echo -e "${GREEN}✔${NC} $1"; }
fail(){ echo -e "${RED}✘${NC} $1"; }
warn(){ echo -e "${YELLOW}•${NC} $1"; }

check_file(){ [[ -f "$1" ]] && pass "exists: $1" || fail "missing: $1"; }
check_grep(){ rg -n "$2" "$1" >/dev/null 2>&1 && pass "found '$2' in $1" || fail "not found '$2' in $1"; }

if ! command -v rg >/dev/null 2>&1; then
  warn "ripgrep(rg) 미설치 → brew install ripgrep 권장. 대체로 grep 사용"
  alias rg='grep -R'
fi

echo "== Stage 0 =="
check_file "pubspec.yaml"
check_file "lib/main.dart"
rg -n "version:" pubspec.yaml >/dev/null 2>&1 && pass "pubspec version set" || warn "version not set"
rg -n "InMemoryRepo" lib/main.dart >/dev/null 2>&1 && pass "main uses InMemoryRepo" || fail "main not wiring InMemoryRepo?"

echo "== Stage 1 =="
check_file "lib/src/repos/repo_views.dart"
rg -n "class .*RepoView" lib/src/repos/repo_views.dart >/dev/null 2>&1 && pass "RepoView class present" || fail "RepoView class missing"
rg -n "Listenable" lib/src/repos/repo_views.dart >/dev/null 2>&1 && warn "RepoView references Listenable? ensure it's NOT Listenable" || pass "RepoView not Listenable (good)"

echo "== Stage 2 =="
check_file "lib/src/models/work.dart"
check_file "lib/src/models/purchase.dart"
check_file "lib/src/repos/repo_interfaces.dart"
check_file "lib/src/repos/inmem_repo.dart"
rg -n "class Work" lib/src/models/work.dart >/dev/null 2>&1 && pass "Work model" || fail "Work model missing"
rg -n "class Purchase" lib/src/models/purchase.dart >/dev/null 2>&1 && pass "Purchase model" || fail "Purchase model missing"

echo "== Stage 3 =="
check_file "lib/src/services/shortage_service.dart"
rg -n "ShortageService" lib/src/services/shortage_service.dart >/dev/null 2>&1 && pass "ShortageService defined" || fail "ShortageService missing"

echo "== Stage 4 =="
check_file "lib/src/screens/work/work_list_screen.dart"
check_file "lib/src/screens/work/work_detail_screen.dart"
rg -n "WorkStatus" lib/src/models/work.dart lib/src/screens/work/* >/dev/null 2>&1 && pass "WorkStatus used" || warn "WorkStatus not referenced in screens?"

echo "== Flutter build smoke =="
if command -v flutter >/dev/null 2>&1; then
  (flutter analyze >/dev/null 2>&1 && pass "flutter analyze OK") || fail "flutter analyze has issues"
else
  warn "flutter CLI not found in PATH; skip analyze"
fi

echo "Done."
