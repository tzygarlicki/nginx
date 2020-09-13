class nginx::config
{ 
  file { '/etc/nginx/sites-enabled/default':
    ensure => absent,
  }
 
  file { '/etc/nginx/nginx.conf':
    ensure  => file,
    notify  => Service['nginx'],
    content => template('nginx/nginx.conf.erb'),
  }

  file { '/etc/nginx/conf.d/logging.conf':
    ensure  => file,
    content => template('nginx/logging.conf.erb'),
  }

  file { '/etc/nginx/ssl':
    ensure => directory,
    path   => '/etc/nginx/ssl',
  }

  file { '/etc/ngnix/ssl/cert.crt':
    ensure => file,
    path   => '/etc/nginx/ssl/cert.crt',
    source => 'puppet:///modules/nginx/cert.crt',
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  file { '/etc/ngnix/ssl/cert.key':
    ensure => file,
    path   => '/etc/nginx/ssl/cert.key',
    source => 'puppet:///modules/nginx/cert.key',
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
  }

  file { '/etc/nginx/sites-available/proxy.conf':
    ensure  => file,
    notify => Service['nginx'],
    content => template('nginx/vh_proxy.conf.erb'),
  }

  file { '/etc/nginx/sites-enabled/proxy.conf':
    ensure => link,
    notify => Service['nginx'],
    target => '/etc/nginx/sites-available/proxy.conf',
  }

  file { "/etc/nginx/sites-available/${nginx::reverse_Domain}.conf":
    ensure  => file,
    notify => Service['nginx'],
    content => template('nginx/vh_reverse.conf.erb'),
  }

  file { "/etc/nginx/sites-enabled/${nginx::reverse_Domain}.conf":
    ensure => link,
    notify => Service['nginx'],
    target => "/etc/nginx/sites-available/${nginx::reverse_Domain}.conf",
  }
}

