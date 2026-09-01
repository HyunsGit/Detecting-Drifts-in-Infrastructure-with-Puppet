class security_hardening::sshd_oom_protection {
  file { '/etc/systemd/system/ssh.service.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/etc/systemd/system/ssh.service.d/oom-protect.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "[Service]\nOOMScoreAdjust=-1000\n",
    notify  => Exec['systemd-daemon-reload-ssh'],
  }

  exec { 'systemd-daemon-reload-ssh':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    notify      => Exec['ensure_sshd_runtime_dir'],
  }

  exec { 'ensure_sshd_runtime_dir':
    command     => '/bin/mkdir -p /run/sshd && /bin/chmod 755 /run/sshd',
    refreshonly => true,
    notify      => Service['ssh'],  # ← just reference it directly, no require
  }
}
