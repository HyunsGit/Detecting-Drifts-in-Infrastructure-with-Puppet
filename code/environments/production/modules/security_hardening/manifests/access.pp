class security_hardening::access (
  Array[String]          $managed_users   = lookup('security_hardening::managed_users', Array, 'first', []),
  Hash[String, Integer]  $user_gid_map    = lookup('security_hardening::user_gid_map', Hash, 'first', {}),
  Array[String]          $sudo_users      = lookup('security_hardening::sudo_users', Array, 'first', []),
  String                 $ssh_banner_path = lookup('security_hardening::ssh_banner_path', String, 'first', '/etc/issue'),
) {

  # SUDO
  class { 'sudo':
    purge            => false,
    config_file      => '/etc/sudoers',
    config_file_mode => '0440',
  }

  $sudo_users.each |String $user| {
    sudo::conf { $user:
      priority => 10,
      content  => "${user} ALL=(ALL) NOPASSWD:ALL",
      require  => Class['sudo'],
    }
  }

  # OS-specific AllowUsers
  $ssh_allow_users = $facts['os']['name'] ? {
    'Ubuntu' => 'AllowUsers scv probe drone marine zealot ubuntu postgres',
    'Rocky'  => 'AllowUsers scv probe drone marine zealot rocky',
    default  => 'AllowUsers scv probe drone marine zealot root',
  }

  # Content of override file
  $override_content = @("EOF")
Banner ${ssh_banner_path}
${ssh_allow_users}
PasswordAuthentication yes
| EOF

  file { '/etc/ssh/sshd_config.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/ssh/sshd_config.d/99-security_hardening.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => $override_content,
    notify  => Exec['validate_sshd_config'],  # Changed: notify validation only
    require => File['/etc/ssh/sshd_config.d'],
  }

  # SSH login banner file
  file { $ssh_banner_path:
    ensure  => file,
    content => lookup('security_hardening::ssh_banner_content', String, 'first', ''),
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    notify  => Exec['validate_sshd_config'],
  }

  # Ordering: sudo → config → banner → validation (no service force)
  Class['sudo']
    -> File['/etc/ssh/sshd_config.d']
    -> File['/etc/ssh/sshd_config.d/99-security_hardening.conf']
    -> File[$ssh_banner_path]
}
