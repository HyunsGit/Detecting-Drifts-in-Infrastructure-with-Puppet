# Detecting Drifts in Infrastructure with Puppet

> KakaoCloud 환경에서 Puppet을 사용해 인프라 상태를 지속적으로 수렴(enforce)하고,  
> 실제 서버 상태와 선언된 코드 간의 **드리프트(Drift)를 자동 감지·복구**하는 구성 관리를 목적으로 함.

---

## Overview

| 항목 | 내용 |
|---|---|
| **Puppet Master** | `puppet-master.internal.example.com` |
| **Run Interval** | 1시간마다 자동 적용 (`runinterval = 1h`) |
| **Report Backend** | PuppetDB (`storeconfigs_backend = puppetdb`) |
| **지원 OS** | Ubuntu, Rocky Linux |
| **환경(Environment)** | `production`, `sandbox`, `pi`, `local` |

Puppet의 **선언적 구성(Declarative Configuration)** 모델을 활용하여, 에이전트가 매 실행마다 서버 상태를 desired state와 비교합니다. 드리프트가 발생하면 Puppet이 자동으로 수렴(remediate)하고, PuppetDB에 변경 이력이 기록.

---

## Architecture

```
Puppet Master (PuppetDB + CA)
        │
        │  HTTPS (8140)   [30min ~ 1h catalog 요청]
        │
   ┌────┴────┐
   │ Puppet  │  ←── hieradata (node-specific override)
   │ Agent   │  ←── site.pp  (node default 적용)
   └────┬────┘
        │
   ┌────▼──────────────────────────────────┐
   │           Custom Modules              │
   │  security_hardening │ monitoring      │
   │  networking         │ time            │
   └───────────────────────────────────────┘
```

**Drift Detection 흐름:**
1. Agent가 주기적으로 Master에 catalog 요청
2. Master가 Hiera 데이터 + 모듈 기반으로 desired state catalog 컴파일
3. Agent가 현재 서버 상태와 catalog 비교
4. 차이(Drift)가 있으면 즉시 수렴 적용
5. 결과를 PuppetDB에 리포트 (changed / unchanged / failed)

---

## Module Structure

```
code/environments/production/
├── manifests/
│   └── site.pp                    # 모든 노드에 4개 모듈 적용
├── hiera.yaml                     # 계층적 데이터 조회 설정
├── data/
│   └── common.yaml                # 환경 공통 Hiera 데이터
├── hieradata/
│   └── nodes/                     # 노드별 개별 override
└── modules/
    ├── security_hardening/        # 보안 강화
    ├── monitoring/                # 모니터링 에이전트
    ├── networking/                # 네트워크 설정
    └── time/                      # 시간 동기화
```

---

## Modules

### `security_hardening` — 보안 강화 및 드리프트 감지

서버 보안 설정의 핵심으로, 수동 변경이나 잘못된 설정이 가해지더라도 **매 실행마다 원하는 상태로 복원**.

| 서브클래스 | 관리 대상 | 드리프트 감지 항목 |
|---|---|---|
| `ssh` | sshd_config | PermitRootLogin, PasswordAuth, Port |
| `ssh_client` | ~/.ssh/config | 사용자별 SSH 클라이언트 설정 |
| `sshd_oom_protection` | systemd override | OOMScoreAdjust=-1000 |
| `accounts` | user/group | UID/GID, 패스워드 해시, 홈디렉토리 권한 |
| `pam` | /etc/login.defs, pwquality.conf | 패스워드 정책 (최대 90일, 최소 8자) |
| `access` | sudoers, /etc/issue | sudo 권한, SSH AllowUsers, 로그인 배너 |
| `files` | /etc/shadow, /etc/hosts 등 | 파일 권한 (0400, 0644 등) |
| `cron` | /etc/cron*, /usr/bin/crontab | cron 디렉토리 권한 |
| `shell` | /etc/profile | umask 022, TMOUT 제거 |
| `packages` | apt/dnf 패키지 | 필수 패키지 `ensure => latest` |
| `ulimits` | /etc/security/limits.conf | nofile/nproc 655350 |

**Noop 모드 지원**: Hiera에서 `noop_mode: true` 설정 시 실제 변경 없이 드리프트만 리포트.

```puppet
# site.pp
$noop_mode = lookup('noop_mode', Boolean, 'first', false)
if $noop_mode {
  noop()
}
```

---

### `monitoring` — 모니터링 에이전트 상태 관리

모니터링 에이전트가 예기치 않게 중단되거나 설정이 변경되어도 자동으로 복구.

| 컴포넌트 | 버전 | 역할 |
|---|---|---|
| **Filebeat** | 8.17.10 | 시스템 로그 → Elasticsearch 전송 |
| **Node Exporter** | 1.6.0 | 호스트 메트릭 → Prometheus 수집 |
| **Promtail** | 2.8.1 | 로그 → Grafana Loki 전송 |

- OS별(Ubuntu/Rocky) 패키지 자동 분기 설치
- systemd 서비스 파일 드리프트 시 `daemon-reload` + 서비스 재시작
- UID/GID 고정 (`node_exporter: uid=1200, gid=1200`)

---

### `networking` — 네트워크 설정 강제 수렴

Ubuntu 노드에서 cloud-init에 의해 DNS 설정이 초기화되는 것을 방지.

- `/etc/netplan/50-cloud-init.yaml` 관리 (ERB 템플릿)
- cloud-init 네트워크 설정 비활성화 (`99-disable-network-config.cfg`)
- 변경 시 `netplan apply` 자동 실행

---

### `time` — 시간 동기화 설정

| OS | 방식 | NTP 서버 |
|---|---|---|
| Ubuntu | systemd-timesyncd | `ntp.internal.example.com` |
| Rocky | chrony | `ntp.internal.example.com` |

- `fstrim.timer` 스케줄 관리 (UTC: 토 17:00, KST: 일 02:00)

---

## Hiera — 계층적 데이터 관리

```yaml
# hiera.yaml
hierarchy:
  - name: "Node-specific overrides"
    path: "nodes/%{trusted.certname}.yaml"   # 노드별 개별 설정
  - name: "security_hardening defaults"
    path: "../modules/security_hardening/data/common.yaml"
  - name: "monitoring defaults"
    path: "../modules/monitoring/data/common.yaml"
  ...
```

노드별 override 예시 (`hieradata/nodes/<hostname>.yaml`):
```yaml
# 특정 노드에서 패키지 제외
security_hardening::packages::exclude:
  - nfs-common

# noop 모드로 드리프트 확인만
noop_mode: true
```

---

## Environments

| 환경 | 용도 |
|---|---|
| `production` | 운영 서버 (실제 enforce) |
| `sandbox` | 스테이징/검증 환경 |
| `pi` | 특정 프로젝트 격리 환경 |
| `local` | 로컬 테스트 환경 |

각 환경은 동일한 모듈 구조를 가지며, Hiera 데이터를 통해 환경별 값을 다르게 적용.

---

## Operations

### 인증서 폐기 (노드 제거 시)

```bash
# revoke_all_cert_including_puppetdb.sh
# PuppetDB에서 노드 비활성화 + 인증서 폐기/정리
./revoke_all_cert_including_puppetdb.sh
```

### 수동 에이전트 실행

```bash
# 즉시 카탈로그 적용
puppet agent -t

# Noop 모드로 드리프트만 확인
puppet agent -t --noop
```

### 드리프트 리포트 조회 (PuppetDB)

```bash
# 변경이 발생한 노드 목록
curl -X GET https://<puppetdb>:8081/pdb/query/v4/reports \
  -d '["=", "status", "changed"]'

# 특정 리소스의 드리프트 이력
curl -X GET https://<puppetdb>:8081/pdb/query/v4/events \
  -d '["=", "resource-type", "File"]'
```

---

## Tech Stack

- **Puppet** 8.x (Server + Agent)
- **PuppetDB** — 리포트 저장 및 노드 인벤토리
- **Hiera 5** — 계층적 설정 데이터 관리
- **KakaoCloud** — 인프라 환경
- **Ubuntu 22.04 / Rocky Linux 9** — 지원 OS
- **Filebeat + Node Exporter + Promtail** — 모니터링 스택
