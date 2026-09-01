class security_hardening::ulimits (
  Integer $nofile_limit = lookup('security_hardening::limits::nofile', Integer, 'first', 655350),
  Integer $nproc_limit = lookup('security_hardening::limits::nproc', Integer, 'first', 655350),
) {

  # ===== /etc/security/limits.conf 직접 관리 =====

  file_line { 'root_nofile_soft':
    ensure => present,
    path   => '/etc/security/limits.conf',
    line   => "root soft nofile ${nofile_limit}",
    match  => '^root\s+soft\s+nofile',
  }

  file_line { 'root_nofile_hard':
    ensure => present,
    path   => '/etc/security/limits.conf',
    line   => "root hard nofile ${nofile_limit}",
    match  => '^root\s+hard\s+nofile',
  }

  file_line { 'all_nofile_soft':
    ensure => present,
    path   => '/etc/security/limits.conf',
    line   => "* soft nofile ${nofile_limit}",
    match  => '^\*\s+soft\s+nofile',
  }

  file_line { 'all_nofile_hard':
    ensure => present,
    path   => '/etc/security/limits.conf',
    line   => "* hard nofile ${nofile_limit}",
    match  => '^\*\s+hard\s+nofile',
  }

  file_line { 'root_nproc_soft':
    ensure => present,
    path   => '/etc/security/limits.conf',
    line   => "root soft nproc ${nproc_limit}",
    match  => '^root\s+soft\s+nproc',
  }

  file_line { 'root_nproc_hard':
    ensure => present,
    path   => '/etc/security/limits.conf',
    line   => "root hard nproc ${nproc_limit}",
    match  => '^root\s+hard\s+nproc',
  }

  file_line { 'all_nproc_soft':
    ensure => present,
    path   => '/etc/security/limits.conf',
    line   => "* soft nproc ${nproc_limit}",
    match  => '^\*\s+soft\s+nproc',
  }

  file_line { 'all_nproc_hard':
    ensure => present,
    path   => '/etc/security/limits.conf',
    line   => "* hard nproc ${nproc_limit}",
    match  => '^\*\s+hard\s+nproc',
  }
}
