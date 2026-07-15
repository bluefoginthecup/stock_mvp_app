# 경영박사 변환기

경영박사 `DR.mdb`를 찰스톡 앱에서 가져올 수 있는
`chalstock_dr_import.zip`으로 변환하는 도구입니다.

## 변환 결과

ZIP에는 다음 파일이 들어갑니다.

- `manifest.json`
- `items.csv`
- `suppliers.csv`
- `purchase_orders.csv`
- `purchase_lines.csv`

정책:

- 경영박사 품목 재고는 `0`으로 가져옵니다.
- 발주 기록만 가져오고 재고 입출고 내역은 만들지 않습니다.
- ID는 `dr_` 접두어로 만들어 재실행 시 같은 데이터를 덮어쓸 수 있게 합니다.

## Mac 개발/검증용 실행

Mac에서는 `mdbtools`가 필요합니다.

```bash
brew install mdbtools
python3 tool/dr_mdb_to_chalstock_zip.py \
  --mdb /Users/bluefog/Downloads/drmdb/DR.mdb \
  --out /private/tmp/chalstock_dr_import.zip
```

## Windows exe 빌드

Windows에서 Python을 설치한 뒤 `tool` 폴더에 있는
`build_dr_converter_windows.bat`을 실행하면 됩니다.

명령 프롬프트에서 직접 실행하려면:

```powershell
cd tool
py -m pip install -r dr_converter_requirements.txt
py -m PyInstaller dr_converter_windows.spec
```

결과:

```text
tool\dist\경영박사변환기.exe
```

Windows에서 `mdbtools`를 같이 배포하지 않는 1차 버전은
Microsoft Access Database Engine 또는 Access ODBC 드라이버가 필요할 수 있습니다.

## Windows 사용 예

```powershell
경영박사변환기.exe --mdb C:\DrCloud\DR.mdb --out C:\Users\me\Desktop\chalstock_dr_import.zip
```

다음 단계에서 찰스톡 앱은 이 ZIP을 선택해 미리보기 후 가져오면 됩니다.
