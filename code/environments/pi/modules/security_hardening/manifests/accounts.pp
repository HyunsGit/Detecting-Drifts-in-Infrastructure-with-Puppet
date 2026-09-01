class security_hardening::accounts (
  Array[String]        $managed_users     = [
    'scv', 'probe', 'drone', 'marine', 'zealot'
  ],
  Hash[String, Integer] $user_gid_map     = {
    'scv'    => 300,
    'probe'  => 301,
    'drone'  => 302,
    'marine' => 303,
    'zealot' => 304,
  },
  Hash[String, Integer] $user_uid_map     = {
    'scv'    => 300,
    'probe'  => 301,
    'drone'  => 302,
    'marine' => 303,
    'zealot' => 304,
  },
  Hash[String, String]  $user_password_hash = {
    'scv'    => '$6$REDACTED$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
    'probe'  => '$6$REDACTED$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
    'drone'  => '$6$REDACTED$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
    'marine' => '$6$REDACTED$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
    'zealot' => '$6$REDACTED$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
  },
) {

  # ===== 그룹 생성 (GID 명시) =====
  $user_gid_map.each |String $user, Integer $gid| {
    group { $user:
      ensure => present,
      gid    => $gid,
    }
  }

  # ===== 사용자 생성 (Puppet 8.x SAFE - No fail()) =====
  $managed_users.each |String $user| {
    # Direct access with safe defaults (no fail()!)
    $uid = $user_uid_map[$user] ? {
      undef   => 300,
      default => $user_uid_map[$user],
    }
    $gid = $user_gid_map[$user] ? {
      undef   => $uid,  # Fallback to UID
      default => $user_gid_map[$user],
    }
    $password_hash = $user_password_hash[$user] ? {
      undef   => '*',   # Locked account fallback
      default => $user_password_hash[$user],
    }

    user { $user:
      ensure     => present,
      uid        => $uid,
      gid        => $gid,
      home       => "/home/${user}",
      shell      => '/bin/bash',
      password   => $password_hash,
      managehome => true,
      require    => Group[$user],
    }
  }

  # ===== 홈디렉토리 권한 설정 ===== (unchanged)
  $managed_users.each |String $user| {
    $home_path = "/home/${user}"
    file { $home_path:
      ensure  => directory,
      owner   => $user,
      group   => $user,
      mode    => '0755',
      require => User[$user],
    }
  }

  # ===== U06: 홈디렉토리 재귀 권한 수정 (FIXED - Safe facts access) =====
  $managed_users.each |String $user| {
    $home_path = "/home/${user}"

    # SAFE facts['files'] access - FIXES line 92 error
    $home_files = $facts['files'] ? {
      undef   => {},
      default => $facts['files'],
    }
    if $home_files[$home_path] {

      # SAFE facts['passwd'] access
      $passwd_exists = $facts['passwd'] ? {
        undef   => false,
        default => true
      }

      $has_mysql = $passwd_exists and ($facts['passwd']['mysql'] ? {
        undef   => false,
        default => true
      })

      if $has_mysql {
        exec { "chown_home_${user}_with_mysql":
          command => "find ${home_path} -not \\( -user root -o -user mysql \\) -exec chown ${user}:${user} {} +",
          path    => ['/bin', '/usr/bin'],
          onlyif  => "test -d ${home_path}",
          require => User[$user],
        }
      } else {
        exec { "chown_home_${user}_no_mysql":
          command => "find ${home_path} -not -user root -exec chown ${user}:${user} {} +",
          path    => ['/bin', '/usr/bin'],
          onlyif  => "test -d ${home_path}",
          require => User[$user],
        }
      }
    }
  }
}
