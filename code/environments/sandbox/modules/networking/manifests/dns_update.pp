class networking::dns_update (
  String $netplan_file = '/etc/netplan/50-cloud-init.yaml',
) {
  if $facts['os']['name'] == 'Ubuntu' {
    # Dynamic: first ethernet interface + its MAC (works all nodes)
    $interfaces = $facts['networking']['interfaces'].filter |$name, $data| { $name =~ /^enp/ }
    $primary_if = $interfaces.keys[0] ? { undef => 'enp3s0', default => $interfaces.keys[0] }
    $macaddress = $facts['networking']['interfaces'][$primary_if]['mac'] ? {
      undef   => 'fa:16:3e:fd:d6:8c',
      default => $facts['networking']['interfaces'][$primary_if]['mac'],
    }

    file { $netplan_file:
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => template('networking/dns_update.erb'),
      notify  => Exec['netplan_apply'],
    }

    # Lock cloud-init
    file { '/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg':
      ensure  => file,
      content => "network: {config: disabled}\n",
      mode    => '0644',
    }

    exec { 'netplan_apply':
      command     => 'netplan apply',
      path        => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
      refreshonly => true,
      timeout     => 30,
    }
  }
}
