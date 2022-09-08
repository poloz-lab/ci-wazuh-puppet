class { 'wazuh::manager':
}
class { 'wazuh::indexer':
  require => [
    Class['wazuh::repo'],
    Exec['apt_update'],
  ],
}
class { 'wazuh::filebeat_oss':
  require => [
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
