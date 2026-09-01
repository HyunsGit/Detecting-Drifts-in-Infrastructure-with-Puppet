# security_hardening::pam
#
# Manages PAM password quality and enforces password aging on BOTH
# new users (via /etc/login.defs) and existing users (via chage).
#
# Parameters:
#   manage_pwquality  - Whether to install/configure libpam-pwquality
#   pass_max_days     - Maximum number of days a password is valid
#   pass_min_days     - Minimum days between password changes
#   pass_min_len      - Minimum password length (login.defs)
#   pass_warn_age     - Days before expiry to warn the user
#   target_users      - Explicit list of users to enforce password aging on.
#                       When set, ONLY these users are targeted — UID-based
#                       selection is bypassed entirely.

class security_hardening::pam (
  Boolean       $manage_pwquality = lookup('security_hardening::pam::manage_pwquality', Boolean, 'first', true),
  Integer       $pass_max_days    = lookup('security_hardening::pam::pass_max_days',    Integer, 'first', 90),
  Integer       $pass_min_days    = lookup('security_hardening::pam::pass_min_days',    Integer, 'first', 1),
  Integer       $pass_min_len     = lookup('security_hardening::pam::pass_min_len',     Integer, 'first', 8),
  Integer       $pass_warn_age    = lookup('security_hardening::pam::pass_warn_age',    Integer, 'first', 7),
  Array[String] $target_users     = lookup('security_hardening::pam::target_users',     Array,   'first', ['scv','probe','drone','marine','zealot']),
) {

  # --------------------------------------------------------------------------
  # 1. OS-specific pwquality package + config
  # --------------------------------------------------------------------------
  if $manage_pwquality {
    if $facts['os']['family'] == 'Debian' {
      package { 'libpam-pwquality':
        ensure => installed,
      }
      file { '/etc/security/pwquality.conf':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('security_hardening/pwquality.conf.erb'),
        require => Package['libpam-pwquality'],
      }
    } elsif $facts['os']['family'] == 'RedHat' {
      package { 'libpwquality':
        ensure => installed,
      }
      file { '/etc/security/pwquality.conf':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('security_hardening/pwquality.conf.erb'),
        require => Package['libpwquality'],
      }
    }
  }

  # --------------------------------------------------------------------------
  # 2. /etc/login.defs — applies to NEW users created after this run
  # --------------------------------------------------------------------------
  file_line { 'PASS_MIN_LEN':
    path  => '/etc/login.defs',
    line  => "PASS_MIN_LEN   ${pass_min_len}",
    match => '^PASS_MIN_LEN',
  }

  file_line { 'PASS_MAX_DAYS':
    path  => '/etc/login.defs',
    line  => "PASS_MAX_DAYS  ${pass_max_days}",
    match => '^PASS_MAX_DAYS',
  }

  file_line { 'PASS_MIN_DAYS':
    path  => '/etc/login.defs',
    line  => "PASS_MIN_DAYS  ${pass_min_days}",
    match => '^PASS_MIN_DAYS',
  }

  file_line { 'PASS_WARN_AGE':
    path  => '/etc/login.defs',
    line  => "PASS_WARN_AGE  ${pass_warn_age}",
    match => '^PASS_WARN_AGE',
  }

  # --------------------------------------------------------------------------
  # 3. Ensure chage binary is available via OS-specific package
  #    - shadow-utils on RedHat family
  #    - passwd on Debian family
  # --------------------------------------------------------------------------
  $chage_package = $facts['os']['family'] ? {
    'Debian' => 'passwd',
    'RedHat' => 'shadow-utils',
    default  => 'shadow-utils',
  }

  package { $chage_package:
    ensure => installed,
  }

  # --------------------------------------------------------------------------
  # 4. chage — enforce password aging on EXPLICIT target_users only
  #
  #    WHY explicit list instead of UID range:
  #      UID ranges like >= 300 would catch unintended accounts in 400-999.
  #      An explicit list is safer — only named users are ever touched.
  #
  #    WHY env vars + single-quoted bash:
  #      Puppet expands ALL $var in double-quoted heredocs at catalog compile
  #      time — including bash loop vars like $u — causing "Unknown variable"
  #      on the Puppet server. Fix: expand Puppet vars into bash env vars in
  #      the outer string, then keep bash logic in single-quoted bash -c '...'
  #      so Puppet never sees $u.
  #
  #    Idempotency:
  #      onlyif checks each target user's current PASS_MAX_DAYS via chage -l.
  #      If all users already match the target value, the exec is skipped.
  # --------------------------------------------------------------------------

  # Join the array into a space-separated string for bash iteration
  $target_users_str = join($target_users, ' ')

  $chage_command = "MAX=${pass_max_days} MIN_DAYS=${pass_min_days} WARN=${pass_warn_age} USERS='${target_users_str}' /bin/bash -c 'for u in \$USERS; do chage --maxdays \"\$MAX\" --mindays \"\$MIN_DAYS\" --warndays \"\$WARN\" \"\$u\"; done'"

  $chage_onlyif  = "MAX=${pass_max_days} USERS='${target_users_str}' /bin/bash -c 'for u in \$USERS; do chage -l \"\$u\" 2>/dev/null | awk -F\": \" \"/Maximum number of days/{print \\\$2}\"; done | grep -qv \"^\$MAX\$\"'"

  exec { 'enforce_password_aging_existing_users':
    command  => $chage_command,
    onlyif   => $chage_onlyif,
    provider => shell,
    require  => [
      Package[$chage_package],
      File_line['PASS_MAX_DAYS'],
      File_line['PASS_MIN_DAYS'],
      File_line['PASS_WARN_AGE'],
    ],
  }
}
