class time (
  String $ubuntu_ntp_server = lookup('time::ntp::ubuntu_server', {'value_type' => String, 'default_value' => 'ntp.internal.example.com'}),
  String $rocky_ntp_server = lookup('time::ntp::rocky_server', {'value_type' => String, 'default_value' => 'ntp.internal.example.com'}),
  Boolean $manage_facts = false,
  Boolean $manage_ntp = true,
  Boolean $manage_fstrim_timer = true,
) {
  if $manage_facts {
    class { 'time::gather_ntp_facts': }
  }
  if $manage_ntp {
    class { 'time::ntp':
      ubuntu_ntp_server => $ubuntu_ntp_server,
      rocky_ntp_server  => $rocky_ntp_server,
    }
  }
  if $manage_fstrim_timer {
    class { 'time::fstrim_timer': }
  }
}
