# TunnelBar

macOS 메뉴바에서 SSH 포트포워딩 터널을 관리하는 작은 앱.
옛 "SSH Tunnel Manager"류 앱의 무료 대체용으로, 내장 `ssh`만 사용하므로
macOS 업데이트로 깨질 일이 없습니다.

## 기능
- 메뉴바 아이콘 → 터널별 **연결/해제** 토글, 상태 점(초록=연결·노랑=연결중·빨강=에러·회색=끊김)
- 편집 창에서 호스트/유저/포트 + **포트포워딩(-L) 목록**을 표로 추가·삭제
- 비밀번호는 **macOS Keychain**에 저장, 연결 시 askpass 헬퍼가 자동 입력
- 앱 시작 시 **자동 연결**(터널별 Autostart) 옵션

## 빌드
```bash
./build.sh            # TunnelBar.app 생성 (release)
open ./TunnelBar.app  # 실행 → 메뉴바에 아이콘
```
요구사항: Xcode(또는 Command Line Tools)의 Swift 6 / macOS 14+.

## 설치 (선택)
```bash
cp -R TunnelBar.app /Applications/        # 앱 폴더로 이동
```
**로그인 시 자동 실행:** 시스템 설정 → 일반 → 로그인 항목 → `+` → TunnelBar.app 추가.

## 첫 사용
1. 메뉴바 아이콘 → **터널 편집…** → `+`로 터널 추가
2. 호스트/유저/포트 + **포트포워딩** 입력
3. **비밀번호** 칸에 입력 → **저장**. (Keychain에 저장됨)
4. 메뉴바에서 **연결** 클릭. 첫 연결 때 Keychain 접근 허용 팝업이 한 번 뜨면 **항상 허용**.

## 데이터 위치
- 설정: `~/Library/Application Support/TunnelBar/tunnels.json`
- askpass 헬퍼: `~/Library/Application Support/TunnelBar/askpass.sh` (자동 생성)
- 비밀번호: 로그인 Keychain, 서비스명 `TunnelBar`

## 비밀번호 대신 SSH 키 쓰기 (권장·더 깔끔)
키를 한 번 등록해두면 비밀번호 저장 자체가 불필요합니다.
```bash
ssh-keygen -t ed25519            # 키 없으면 생성
ssh-copy-id user@server.example.com   # 서버에 공개키 등록 (이때 한 번 비밀번호 입력)
```
이후엔 비밀번호 칸을 비워둬도 연결됩니다.

## 동작 원리
각 터널은 아래와 동등한 명령을 백그라운드 프로세스로 실행합니다:
```
ssh -v -N -o ConnectTimeout=15 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new \
    -L localhost:3535:10.0.0.7:22 -L localhost:3737:10.0.3.152:22 \
    -p 22 user@server.example.com
```
`SSH_ASKPASS` + `SSH_ASKPASS_REQUIRE=force` 로 askpass 헬퍼가 Keychain에서
비밀번호를 읽어 자동 입력합니다.

## 문의
cs@peppercode.co.kr

## 라이선스
[MIT](LICENSE)
