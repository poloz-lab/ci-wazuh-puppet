class { 'wazuh::manager':
}
class { 'wazuh::indexer':
  require => [
    Class['wazuh::repo'],
    Exec['apt_update'],
  ],
}
class { 'wazuh::filebeat_oss':
  wazuh_filebeat_module => 'wazuh-filebeat-0.1.tar.gz',
  require               => [
    Class['wazuh::repo'],
    Exec['apt_update'],
  ],
}
class { 'wazuh::dashboard':
  require => [
    Class['wazuh::repo'],
    Exec['apt_update'],
  ],
}
