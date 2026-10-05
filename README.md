# URE

Unicode Reunion Engine. 분해된 Unicode 파일명을 NFC로 정규화하는 macOS 유틸리티입니다.

A native macOS utility for reuniting decomposed Unicode filenames.

로컬 Xcode 빌드의 마케팅 버전은 1.0.0입니다. GitHub Release 빌드는 Git 태그의 버전을 사용합니다. `v1.2.3`은 앱 버전 `1.2.3`이 됩니다.

## 하는 일

파일과 폴더의 **이름만** NFC(Canonical Composition)로 바꿉니다. 파일 내용은 수정하지 않고, 기존 파일을 덮어쓰지도 않습니다.

- 폴더는 하위 항목까지 처리합니다.
- `.app` 번들은 하나의 항목으로 다루고, 내부는 들어가지 않습니다. 번들 이름 자체는 정규화할 수 있습니다.
- 심볼릭 링크는 따라가지 않고, 건너뛴 항목으로 보여 줍니다.
- 바꾸기 전에 미리보기를 보여 줍니다.
- 같은 위치에 이미 그 이름이 있으면 그 항목만 실패로 남기고 나머지는 계속합니다.
- 마지막 실행은 실행 취소할 수 있습니다. 취소도 덮어쓰지 않습니다.

NFD를 NFC로만 바꿉니다. NFKC나 NFKD는 사용하지 않습니다.

## 사용

1. 파일 또는 폴더를 창에 놓거나 **파일 선택**으로 고릅니다.
2. 미리보기에서 바뀔 이름을 확인합니다.
3. **정규화 실행**을 누릅니다.
4. 결과에서 변경, 변경 없음, 실패 개수를 확인합니다. 직전 실행은 **실행 취소**로 되돌릴 수 있습니다.

권한이 없으면 앱은 멈추지 않고 해당 항목을 실패로 표시합니다. 다시 실행한 뒤, 나타나는 창에서 그 파일이 들어 있는 폴더 접근을 허용하면 그 항목만 다시 시도합니다.

## 빌드

macOS 27과 Xcode 27이 필요합니다.

`URE.xcodeproj`를 열고 스킴 **URE**로 Run합니다. 테스트는 같은 스킴의 Test로 실행합니다.

## 배포

macOS 27 SDK가 필요해서 GitHub Actions는 `xcode-27` runner에서 Release 빌드를 만듭니다. `v1.2.3` 형태의 태그를 push하면 workflow가 ZIP, DMG, `appcast.xml`을 만들어 GitHub Release에 올립니다. `-alpha`, `-beta`, `-rc`가 들어간 태그는 prerelease입니다.

업데이트 확인 주소는 각 릴리즈에 올라간 `appcast.xml`의 고정 주소입니다.

`https://github.com/OWNER/URE/releases/latest/download/appcast.xml`

앱은 이 주소를 하루에 한 번 확인합니다. 새 버전이 있으면 Sparkle이 버전과 설치 여부를 묻고, 사용자가 설치를 선택해야 다운로드와 재시작이 진행됩니다. 앱 메뉴의 Check for Updates…로 바로 확인할 수도 있습니다.

Sparkle 서명은 EdDSA입니다. 비공개 키는 `SPARKLE_PRIVATE_KEY` GitHub Actions secret으로만 두고, 저장소에는 공개 키만 있습니다.

로컬에서 패키징을 확인하려면 비공개 키를 환경 변수로만 넘깁니다.

```bash
export SPARKLE_PRIVATE_KEY="$(cat ~/.config/ure/sparkle-private-key)"
export URE_APPCAST_URL="https://github.com/OWNER/URE/releases/latest/download/appcast.xml"
export URE_DOWNLOAD_URL_PREFIX="https://github.com/OWNER/URE/releases/download/v0.1.0/"
./Scripts/package_release.sh v0.1.0
```

결과물은 `dist/URE-v0.1.0.zip`, `dist/URE-v0.1.0.dmg`, `dist/appcast.xml`입니다. `OWNER/URE`는 실제 GitHub 저장소로 바꿉니다. `origin` remote가 있으면 두 URL 환경 변수는 생략할 수 있습니다.

DMG를 열면 URE와 응용 프로그램 폴더가 나란히 있습니다. 앱을 그 폴더로 끌어다 놓으면 설치됩니다.

단위 테스트:

```bash
xcodebuild -project URE.xcodeproj -scheme URE -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/URE-derived CODE_SIGNING_ALLOWED=NO test
```

첫 릴리즈:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## 라이선스

[MIT](LICENSE)
