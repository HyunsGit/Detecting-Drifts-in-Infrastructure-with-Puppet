class security_hardening::cron {

  file { '/usr/bin/crontab':
    owner => 'root',
    group => 'root',
    mode  => '0750',
  }

  file { '/etc/crontab':
    owner => 'root',
    group => 'root',
    mode  => '0640',
  }

  ['cron.d','cron.daily','cron.hourly','cron.monthly','cron.weekly','cron.deny'].each |String $p| {
    $full = "/etc/${p}"
    file { $full:
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      recurse => true,
    }
  }

}
