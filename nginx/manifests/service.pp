class nginx::service
{
  service { 'nginx' :
    ensure  => "running",
    enable  => 'true',
    require => Package['nginx'],
  }

  # 'https://puppet.com/docs/puppet/5.5/types/nagios_command.html' may be better
  exec { 'forwardproxy_check':
    command => "if [ $(/usr/bin/curl -x 127.0.0.1:${nginx::proxy_ListenPort} '${nginx::proxy_TestWeb}' -L | grep '${proxy_TestString}' | wc -l) -ge 1 ] ; then exit 0; else exit 1; fi",
    provider => 'shell',
    returns => '0',
  }
}

