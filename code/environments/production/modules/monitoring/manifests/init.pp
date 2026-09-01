class monitoring (
  # Filebeat 설정
  String $filebeat_version  = lookup('monitoring::filebeat::version', {'value_type' => String, 'default_value' => '8.17.10'}),
  String $filebeat_storage  = lookup('monitoring::filebeat::storage_url', {'value_type' => String, 'default_value' => ''}),
  String $filebeat_config   = lookup('monitoring::filebeat::config_path', {'value_type' => String, 'default_value' => '/etc/filebeat-8.17/system-config'}),
  String $filebeat_service  = lookup('monitoring::filebeat::service_name', {'value_type' => String, 'default_value' => 'system-filebeat8'}),

  # Node Exporter 설정
  String $node_exporter_version = lookup('monitoring::node_exporter::version', {'value_type' => String, 'default_value' => '1.6.0'}),
  String $node_exporter_url     = lookup('monitoring::node_exporter::download_url', {'value_type' => String, 'default_value' => ''}),
  String $node_exporter_service = lookup('monitoring::node_exporter::service_name', {'value_type' => String, 'default_value' => 'node_exporter'}),

  # Promtail 설정
  String $promtail_version  = lookup('monitoring::promtail::version', {'value_type' => String, 'default_value' => '2.9.0'}),
  String $promtail_source   = lookup('monitoring::promtail::binary_source', {'value_type' => String, 'default_value' => ''}),
  String $promtail_config   = lookup('monitoring::promtail::config_path', {'value_type' => String, 'default_value' => '/etc/promtail'}),
  String $promtail_service  = lookup('monitoring::promtail::service_name', {'value_type' => String, 'default_value' => 'promtail'}),
) {
  # 1. Filebeat (먼저)
  class { 'monitoring::filebeat':
    version     => $filebeat_version,
    storage_url => $filebeat_storage,
    config_path => $filebeat_config,
    service_name=> $filebeat_service,
  }

  # 2. Node Exporter
  class { 'monitoring::node_exporter':
    version      => $node_exporter_version,
    download_url => $node_exporter_url,
    service_name => $node_exporter_service,
  }

  # 3. Promtail (마지막)
  class { 'monitoring::promtail':
    version       => $promtail_version,
    config_path   => $promtail_config,
    service_name  => $promtail_service,
  }

  # 의존성 순서: filebeat → node_exporter → promtail
  Class['monitoring::filebeat']     -> Class['monitoring::node_exporter']
  Class['monitoring::node_exporter'] -> Class['monitoring::promtail']
}
