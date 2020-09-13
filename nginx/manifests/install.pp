class nginx::install
{
  package { 'nginx':
    ensure => present,
  }

  package { 'curl':
    ensure => present,
  }   
}

