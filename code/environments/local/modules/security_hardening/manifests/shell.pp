class security_hardening::shell {

  file_line { 'profile_tmout':
    ensure  => absent,
    path    => '/etc/profile',
    match   => '^export TMOUT=',
    match_for_absence => true,
  }

  file_line { 'profile_umask':
    path  => '/etc/profile',
    line  => 'umask 022',
    match => '^umask\\s+',
  }
}

