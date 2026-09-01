# Fstrim Timer Configuration Class
# File: /etc/puppet/code/environments/local/modules/time/manifests/fstrim_timer.pp

class time::fstrim_timer (
  String $fstrim_timer_dir = '/etc/systemd/system/fstrim.timer.d',
  String $override_conf_path = '/etc/systemd/system/fstrim.timer.d/override.conf',
) {

  # Create fstrim.timer.d directory
  file { $fstrim_timer_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    recurse => false,
  }

  # Configure fstrim.timer for UTC timezone
  if $::timezone == 'UTC' {
    file { $override_conf_path:
      ensure    => file,
      owner     => 'root',
      group     => 'root',
      mode      => '0644',
      content   => "[Timer]\nOnCalendar=\nOnCalendar=Sat *-*-* 17:00:00\nRandomizedDelaySec=4h\nAccuracySec=1s\nPersistent=true\n",
      replace   => true,
      require   => File[$fstrim_timer_dir],
      notify    => Exec['systemd-daemon-reload'],
    }
  }

  # Configure fstrim.timer for KST timezone
  elsif $::timezone == 'KST' or $::timezone == 'Asia/Seoul' {
    file { $override_conf_path:
      ensure    => file,
      owner     => 'root',
      group     => 'root',
      mode      => '0644',
      content   => "[Timer]\nOnCalendar=\nOnCalendar=Sun *-*-* 02:00:00\nRandomizedDelaySec=4h\nAccuracySec=1s\nPersistent=true\n",
      replace   => true,
      require   => File[$fstrim_timer_dir],
      notify    => Exec['systemd-daemon-reload'],
    }
  }

  # Reload systemd daemon when file changes
  exec { 'systemd-daemon-reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
    path        => '/bin:/usr/bin:/sbin:/usr/sbin',
  }

  # Ensure fstrim.timer service is enabled and running
  service { 'fstrim.timer':
    ensure    => running,
    enable    => true,
    require   => Exec['systemd-daemon-reload'],
  }
}
