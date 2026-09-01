class security_hardening {
  class { 'security_hardening::ssh': }
  class { 'security_hardening::ssh_client': }
  class { 'security_hardening::sshd_oom_protection': }
  class { 'security_hardening::pam': }
  class { 'security_hardening::accounts': }
  class { 'security_hardening::files': }
  class { 'security_hardening::cron': }
  class { 'security_hardening::shell': }
  class { 'security_hardening::node_exporter': }
  class { 'security_hardening::packages': }
  class { 'security_hardening::access': }
  class { 'security_hardening::ulimits': }
}
