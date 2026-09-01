class time::ntp (
  String $ubuntu_ntp_server = lookup('time::ntp::ubuntu_server', String, 'first', 'ntp.internal.example.com'),
  String $rocky_ntp_server  = lookup('time::ntp::rocky_server', String, 'first', 'ntp.internal.example.com'),
) {
  case $facts['os']['name'] {
    'Ubuntu': {
      package { 'systemd-timesyncd':
        ensure => present,
      }
      file { '/etc/systemd/timesyncd.conf':
        ensure  => file,
        content => epp('time/timesyncd.conf.epp', {
          'ntp_server' => $ubuntu_ntp_server,
        }),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        require => Package['systemd-timesyncd'],
        notify  => Exec['systemd_daemon_reload_ntp'],
      }
      exec { 'systemd_daemon_reload_ntp':
        command     => '/usr/bin/systemctl daemon-reload',
        refreshonly => true,
        notify      => Service['systemd-timesyncd'],
      }
      service { 'systemd-timesyncd':
        ensure  => running,
        enable  => true,
        require => [Package['systemd-timesyncd'], File['/etc/systemd/timesyncd.conf']],
      }
    }
    'Rocky': {
      package { 'chrony':
        ensure => present,
      }
      file { '/etc/chrony.conf':
        ensure  => file,
        content => epp('time/chrony.conf.epp', {
          'ntp_server' => $rocky_ntp_server,
          'leapsectz'  => 'right/Asia/Seoul',
        }),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        notify  => Service['chronyd'],
      }
      service { 'chronyd':
        ensure  => running,
        enable  => true,
        require => [Package['chrony'], File['/etc/chrony.conf']],
      }
    }
    default: {
      fail("Unsupported OS: ${facts['os']['name']}")
    }
  }
}
