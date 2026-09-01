class security_hardening::ssh (
  Variant[Boolean,String] $permit_root_login = lookup('security_hardening::ssh::permit_root_login', { 'value_type' => Variant[Boolean,String], 'default_value' => 'no' }),
  Variant[Boolean,String] $password_authentication = lookup('security_hardening::ssh::password_authentication', { 'value_type' => Variant[Boolean,String], 'default_value' => 'no' }),
  Integer $ssh_port = lookup('security_hardening::ssh::port', Integer, 'first', 22),
  String $pubkey_authentication = lookup('security_hardening::ssh::pubkey_authentication', String, 'first', 'yes'),
) {
  $permit_root_str = $permit_root_login ? { true => 'yes', false => 'no', default => $permit_root_login }
  $password_auth_str = $password_authentication ? { true => 'yes', false => 'no', default => $password_authentication }
  case $facts['os']['name'] {
    'Ubuntu': {
      # Permanent fix — recreates /run/sshd on every reboot via systemd-tmpfiles
      file { '/etc/tmpfiles.d/sshd.conf':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "d /run/sshd 0755 root root -\n",
      }

      # Runtime fix — ensures /run/sshd exists right now
      file { '/run/sshd':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      $cloud_config_path = '/etc/ssh/sshd_config.d/60-cloudimg-settings.conf'
      file { $cloud_config_path:
        ensure  => file,
        content => epp('security_hardening/ssh/sshd-cloudimg.conf.epp', {
          'permit_root_login'       => $permit_root_str,
          'password_authentication' => $password_auth_str,
          'ssh_port'                => $ssh_port,
          'pubkey_authentication'   => $pubkey_authentication,
        }),
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        notify  => Exec['validate_sshd_config'],
      }

      exec { 'validate_sshd_config':
        command     => '/usr/sbin/sshd -t',
        refreshonly => true,
        timeout     => 30,
        notify      => Exec['restart_sshd_socket'],
      }

      # Handles both socket-activated and non-socket-activated servers gracefully
      exec { 'restart_sshd_socket':
        command     => '/usr/bin/systemctl restart ssh.socket || /usr/bin/systemctl restart ssh',
        refreshonly => true,
        require     => Exec['validate_sshd_config'],
      }

      service { 'ssh':
        ensure  => running,
        enable  => true,
        require => [
          Exec['validate_sshd_config'],
          File['/run/sshd'],
        ],
      }
    }
    'Rocky': {
      $rocky_cloudimg_exists = $facts['os']['release']['major'] ? {
        '9'     => true,
        '8'     => true,
        default => false,
      }
      if $rocky_cloudimg_exists {
        $cloud_config_path = '/etc/ssh/sshd_config.d/50-cloud-init.conf'
        file { $cloud_config_path:
          ensure  => file,
          content => epp('security_hardening/ssh/sshd-cloudimg.conf.epp', {
            'permit_root_login'       => $permit_root_str,
            'password_authentication' => $password_auth_str,
            'ssh_port'                => $ssh_port,
            'pubkey_authentication'   => $pubkey_authentication,
          }),
          mode    => '0644',
          owner   => 'root',
          group   => 'root',
          notify  => Exec['validate_sshd_config'],
        }
      } else {
        $cloud_config_path = '/etc/ssh/sshd_config'
        file { $cloud_config_path:
          ensure  => file,
          content => epp('security_hardening/ssh/sshd-cloudimg.conf.epp', {
            'permit_root_login'       => $permit_root_str,
            'password_authentication' => $password_auth_str,
            'ssh_port'                => $ssh_port,
            'pubkey_authentication'   => $pubkey_authentication,
          }),
          mode    => '0600',
          owner   => 'root',
          group   => 'root',
          notify  => Exec['validate_sshd_config'],
        }
      }
      exec { 'validate_sshd_config':
        command     => '/usr/sbin/sshd -t',
        refreshonly => true,
        timeout     => 30,
      }
      service { 'sshd':
        ensure     => running,
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        subscribe  => File[$cloud_config_path],
        require    => Exec['validate_sshd_config'],
      }
    }
    default: {
      fail("Unsupported OS: ${facts['os']['name']}")
    }
  }
}
