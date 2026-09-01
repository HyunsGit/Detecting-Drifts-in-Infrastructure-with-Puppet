class time::gather_ntp_facts {
  notify { 'NTP facts available':
    message => "timesyncd_server_name=${facts['timesyncd_server_name']} (collected successfully)",
  }
}

