class security_hardening::files {

  file { '/etc/shadow':
    owner => 'root',
    group => 'root',
    mode  => '0400',
  }

  file { '/etc/hosts':
    owner => 'root',
    group => 'root',
    mode  => '0644',
  }

  file { '/etc/rsyslog.conf':
    owner => 'root',
    group => 'root',
    mode  => '0640',
  }

  file { '/etc/profile':
    owner => 'root',
    group => 'root',
    mode  => '0644',
  }

  # Binaries that must be owned by root and MUST NOT have suid/sgid
  $no_suid_sgid_bins = [
    '/usr/local/bin/crictl',
    '/usr/local/bin/critest',
    '/usr/local/bin/ctr',
    '/usr/bin/at',
    '/usr/bin/write',
    # add more here if needed
  ]

  $no_suid_sgid_bins.each |String $bin| {
    file { $bin:
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',  # rwxr-xr-x
    }
  }

}
