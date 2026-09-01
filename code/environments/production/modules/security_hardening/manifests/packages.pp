class security_hardening::packages {
  include apt
  $all_packages     = lookup('security_hardening::packages', Hash, 'first', {})
  $exclude_packages = lookup('security_hardening::packages::exclude', Array, 'first', [])

  $ubuntu_packages_raw = $all_packages['ubuntu'] ? { undef => [], default => $all_packages['ubuntu'] }
  $rocky_packages_raw  = $all_packages['rocky']  ? { undef => [], default => $all_packages['rocky'] }

  # Filter out excluded packages
  $ubuntu_packages = $ubuntu_packages_raw - $exclude_packages
  $rocky_packages  = $rocky_packages_raw  - $exclude_packages

  notice("Ubuntu pkgs: ${ubuntu_packages}")
  notice("Rocky pkgs: ${rocky_packages}")

  if $facts['os']['name'] == 'Ubuntu' and size($ubuntu_packages) > 0 {
    package { $ubuntu_packages: ensure => latest }
  }
  if $facts['os']['name'] == 'Rocky' and size($rocky_packages) > 0 {
    exec { 'dnf_enable_devel':
      command => '/usr/bin/dnf config-manager --enable devel',
      unless  => '/usr/bin/dnf repolist enabled | /usr/bin/grep -q devel',
    }
    package { $rocky_packages:
      ensure  => latest,
      require => Exec['dnf_enable_devel'],
    }
  }
}
