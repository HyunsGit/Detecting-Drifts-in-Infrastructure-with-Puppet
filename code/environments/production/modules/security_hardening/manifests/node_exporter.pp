class security_hardening::node_exporter {

  if $facts['os']['name'] == 'Ubuntu' {
    $node_exporter_user = 'ubuntu'
  } elsif $facts['os']['name'] == 'Rocky' {
    $node_exporter_user = 'rocky'
  } else {
    $node_exporter_user = 'root'
  }

  file { "/home/${node_exporter_user}/node_exporter-1.6.0.linux-amd64":
    ensure  => directory,
    owner   => $node_exporter_user,
    group   => $node_exporter_user,
    recurse => true
  }
}
