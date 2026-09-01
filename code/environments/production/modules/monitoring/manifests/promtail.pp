class monitoring::promtail (
  String $version      = lookup('monitoring::promtail::version', String, 'first', '2.8.1'),
  String $config_path  = lookup('monitoring::promtail::config_path', String, 'first', '/etc/promtail'),
  String $service_name = lookup('monitoring::promtail::service_name', String, 'first', 'promtail'),
  Boolean $manage      = lookup('monitoring::promtail::manage', Boolean, 'first', true),
) {

  if $manage {

    $promtail_zip = "/tmp/promtail-linux-amd64-${version}.zip"
    $promtail_url = "https://github.com/grafana/loki/releases/download/v${version}/promtail-linux-amd64.zip"
    $promtail_bin = '/usr/local/bin/promtail'

    exec { 'download_promtail':
      command => "/usr/bin/curl -L -f -o ${promtail_zip} '${promtail_url}'",
      creates => $promtail_zip,
      timeout => 300,
    }
    exec { 'extract_promtail':
      command => @("EXTRACT"/L),
        /usr/bin/unzip -j -o ${promtail_zip} promtail-linux-amd64 -d /tmp/ && \
        /bin/rm -f ${promtail_bin} /usr/local/bin/promtail-linux-amd64 && \
        /bin/mv /tmp/promtail-linux-amd64 ${promtail_bin} && \
        /bin/chmod 755 ${promtail_bin}
        | EXTRACT
      unless  => "/usr/bin/test -f ${promtail_bin}",
      require => Exec['download_promtail'],
      notify  => File[$promtail_bin],
    }
    file { $promtail_bin:
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }
    file { $config_path:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }
    file { "${config_path}/logs":
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => File[$config_path],
    }
    file { "${config_path}/promtail-config.yaml":
      ensure  => file,
      content => epp('monitoring/promtail/promtail-config.epp', {
        'node_hostname' => $facts['hostname'],
        'loki_url'      => 'http://grafana.internal.example.com:3100/loki/api/v1/push',
      }),
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => File[$config_path],
      notify  => Service[$service_name],
    }
    file { "/etc/systemd/system/${service_name}.service":
      ensure => file,
      source => 'puppet:///modules/monitoring/promtail/promtail.service',
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      notify => Exec['systemd_daemon_reload_promtail'],
    }
    exec { 'systemd_daemon_reload_promtail':
      command     => '/usr/bin/systemctl daemon-reload',
      refreshonly => true,
      notify      => Service[$service_name],
    }
    service { $service_name:
      ensure  => running,
      enable  => true,
      require => [
        File["/etc/systemd/system/${service_name}.service"],
        File["${config_path}/promtail-config.yaml"],
        File[$promtail_bin],
      ],
    }

  } # end if $manage
}
