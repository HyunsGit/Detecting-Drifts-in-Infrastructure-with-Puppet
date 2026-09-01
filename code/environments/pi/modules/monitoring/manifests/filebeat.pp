class monitoring::filebeat (
  String $version = lookup('monitoring::filebeat::version', String, 'first', '8.17.10'),
  String $storage_url = lookup('monitoring::filebeat::storage_url', String, 'first', 'https://artifacts.elastic.co/downloads/beats/filebeat'),
  String $config_path = lookup('monitoring::filebeat::config_path', String, 'first', '/etc/filebeat-8.17/system-config'),
  String $service_name = lookup('monitoring::filebeat::service_name', String, 'first', 'system-filebeat8'),
) {

  # ===== OS별 패키지 경로 결정 =====
  $pkg_url = $facts['os']['name'] ? {
    'Ubuntu' => "${storage_url}/filebeat-${version}-amd64.deb",
    'Rocky'  => "${storage_url}/filebeat-${version}-x86_64.rpm",
    default  => fail("Unsupported OS: ${facts['os']['name']}"),
  }

  $pkg_name = $facts['os']['name'] ? {
    'Ubuntu' => "filebeat-${version}-amd64.deb",
    'Rocky'  => "filebeat-${version}-x86_64.rpm",
    default  => fail("Unsupported OS: ${facts['os']['name']}"),
  }

  $pkg_path = "/tmp/${pkg_name}"
  $installed_marker = '/usr/share/filebeat/bin/filebeat'  # Check if filebeat is installed

  # ===== Filebeat 패키지 다운로드 =====
  exec { 'download_filebeat':
    command => "/usr/bin/curl -L -f -o ${pkg_path} '${pkg_url}'",
    creates => $installed_marker,  # Only download if not installed
    timeout => 300,
  }

  # ===== Filebeat 패키지 설치 =====
  $filebeat_package = $facts['os']['name'] ? {
    'Ubuntu' => { 'ensure' => present, 'provider' => 'dpkg', 'source' => $pkg_path },
    'Rocky'  => { 'ensure' => present, 'provider' => 'yum', 'source' => $pkg_path },
    default  => fail("Unsupported OS: ${facts['os']['name']}"),
  }

  package { 'filebeat':
    * => $filebeat_package,
    require => Exec['download_filebeat'],
  }

  # ===== 기본 filebeat 서비스 비활성화/중지 =====
  service { 'filebeat':
    ensure     => stopped,
    enable     => false,
    hasrestart => true,
    hasstatus  => true,
    require    => Package['filebeat'],
  }

  # ===== Filebeat 설정 디렉토리 계층 생성 =====
  $config_dir_parent = dirname($config_path)
  file { $config_dir_parent:
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => Package['filebeat'],
  }

  file { $config_path:
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    require => File[$config_dir_parent],
  }

  # ===== Filebeat 모듈 디렉토리 복사 =====
  exec { 'copy_filebeat_modules':
    command => "/usr/bin/cp -r /etc/filebeat/modules.d ${config_path}/",
    creates => "${config_path}/modules.d",  # Only copy if doesn't exist
    require => File[$config_path],
  }

  # ===== Filebeat 설정 파일 (OS별) =====
  $config_source = $facts['os']['name'] ? {
    'Ubuntu' => 'puppet:///modules/monitoring/filebeat/system-filebeat8-ubuntu.yml',
    'Rocky'  => 'puppet:///modules/monitoring/filebeat/system-filebeat8-rocky.yml',
    default  => fail("Unsupported OS: ${facts['os']['name']}"),
  }

  file { "${config_path}/system-filebeat.yml":
    ensure  => file,
    source  => $config_source,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Exec['copy_filebeat_modules'],
    notify  => Service[$service_name],
  }

  # ===== Filebeat Systemd 서비스 파일 =====
  file { "/etc/systemd/system/${service_name}.service":
    ensure => file,
    source => 'puppet:///modules/monitoring/filebeat/system-filebeat8.service',
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    notify => Exec['systemd_daemon_reload_filebeat'],
  }

  # ===== Systemd 리로드 =====
  exec { 'systemd_daemon_reload_filebeat':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    notify      => Service[$service_name],
  }

  # ===== Filebeat 서비스 관리 =====
  service { $service_name:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => [
      File["/etc/systemd/system/${service_name}.service"],
      File["${config_path}/system-filebeat.yml"],
      Service['filebeat'],
    ],
  }
}

