# VS Code i18n Search & Replace Cheatsheet

## 후보 찾기(하드코딩 문자열)
Text 위젯:
```
(Text\s*\(\s*")[^"]+(")
```
Input 라벨/힌트:
```
(labelText|hintText)\s*:\s*"(.*?)"
```
SnackBar/AlertDialog:
```
SnackBar\s*\(\s*content:\s*Text\s*\(\s*"(.*?)"
```
```
AlertDialog\s*\(.*?title:\s*Text\s*\(\s*"(.*?)"
```
```
AlertDialog\s*\(.*?content:\s*Text\s*\(\s*"(.*?)"
```

## const 제거
```
const\s+(Text|AppBar|SnackBar|AlertDialog)\b
```
