class security_hardening::ssh_client (
  Array[String] $managed_users = lookup('security_hardening::ssh_client::managed_users', Array[String], 'first', []),
) {
  $managed_users.each |$user| {
    $ssh_dir = "/home/${user}/.ssh"
    $ssh_config = "${ssh_dir}/config"

    file { $ssh_dir:
      ensure => directory,
      owner  => $user,
      group  => $user,
      mode   => '0700',
    }

    file { $ssh_config:
      ensure  => file,
      owner   => $user,
      group   => $user,
      mode    => '0600',
      content => lookup('security_hardening::ssh_client::config_content', String, 'first', template('security_hardening/ssh_client.erb')),
      require => File[$ssh_dir],
    }
  }
}
