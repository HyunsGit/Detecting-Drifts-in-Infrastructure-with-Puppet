class monitoring::node_exporter (
  String $version = lookup('monitoring::node_exporter::version', String, 'first', '1.6.0'),
  String $download_url = lookup('monitoring::node_exporter::download_url', String, 'first', ''),
  String $service_name = lookup('monitoring::node_exporter::service_name', String, 'first', 'node_exporter'),
  Integer $uid = lookup('monitoring::node_exporter::uid', Integer, 'first', 1200),
  Integer $gid = lookup('monitoring::node_exporter::gid', Integer, 'first', 1200),
  String $home_dir = lookup('monitoring::node_exporter::home_dir', String, 'first', '/home/node_exporter'),
) {

  # ===== Node Exporter 서비스 일시 중지 (UID 변경 전) =====
  exec { 'stop_node_exporter_for_uid_change':
    command => '/usr/bin/systemctl stop node_exporter || true',
    onlyif  => "/usr/bin/id -u node_exporter 2>/dev/null | grep -qv '^${uid}$'",
    path    => '/usr/bin:/bin:/usr/sbin:/sbin',
    before  => User['node_exporter'],
  }

  # ===== Node Exporter 그룹 생성 =====
  group { 'node_exporter':
    ensure => present,
    gid    => $gid,
    system => true,
  }

  # ===== Node Exporter 홈 디렉토리 생성 =====
  file { $home_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # ===== Node Exporter 사용자 생성 =====
  user { 'node_exporter':
    ensure     => present,
    uid        => $uid,
    gid        => 'node_exporter',
    home       => $home_dir,
    managehome => false,
    shell      => '/bin/false',
    system     => true,
    require    => [
      Group['node_exporter'],
      File[$home_dir],
      Exec['stop_node_exporter_for_uid_change'],
    ],
  }

  # ===== Node Exporter 바이너리 다운로드 =====
  $download_path = "/tmp/node_exporter-${version}.linux-amd64.tar.gz"
  $binary_path = '/usr/local/bin/node_exporter'

  exec { 'download_node_exporter':
    command => "/usr/bin/curl -L -o ${download_path} ${download_url}/v${version}/node_exporter-${version}.linux-amd64.tar.gz",
    creates => $binary_path,
    timeout => 300,
    path    => '/usr/bin:/bin:/usr/sbin:/sbin',
  }

  # ===== Node Exporter 바이너리 추출 및 설치 =====
  exec { 'extract_node_exporter':
    command => "/usr/bin/tar -xzf ${download_path} -C /tmp/ && /usr/bin/install -m 0755 /tmp/node_exporter-${version}.linux-amd64/node_exporter ${binary_path}",
    creates => $binary_path,
    require => Exec['download_node_exporter'],
    path    => '/usr/bin:/bin:/usr/sbin:/sbin',
  }

  # ===== Node Exporter 바이너리 권한 설정 =====
  file { $binary_path:
    ensure  => file,
    owner   => 'node_exporter',
    group   => 'node_exporter',
    mode    => '0755',
    require => [Exec['extract_node_exporter'], User['node_exporter']],
  }

  # ===== Node Exporter 환경 변수 파일 =====
  file { '/etc/default/node_exporter':
    ensure => file,
    source => 'puppet:///modules/monitoring/node_exporter/node_exporter_lb',
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => Service[$service_name],
  }

  # ===== Node Exporter Systemd 서비스 파일 =====
  file { "/etc/systemd/system/${service_name}.service":
    ensure => file,
    source => 'puppet:///modules/monitoring/node_exporter/node_exporter.service',
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => Exec['systemd_daemon_reload_node_exporter'],
  }

  # ===== Systemd 리로드 =====
  exec { 'systemd_daemon_reload_node_exporter':
    command     => '/usr/bin/systemctl daemon-reload',
    path        => '/usr/bin:/bin:/usr/sbin:/sbin',
    refreshonly => true,
    notify      => Service[$service_name],
  }

  # ===== Node Exporter 서비스 관리 =====
  service { $service_name:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      File["/etc/systemd/system/${service_name}.service"],
      File[$binary_path],
      File['/etc/default/node_exporter'],
      User['node_exporter'],
    ],
  }
}
