node 'lemp01' {
  class { 'nginx':
      proxy_Resolver       => '8.8.4.4',
      proxy_Allow          => '10.0.0.0/8',
      proxy_AccessLog      => '/var/log/nginx/access_forwardproxy.log',
      proxy_ListenPort     => 81,
      proxy_TestWeb        => 'web01.tzygarlicki.com',
      proxy_TestString     => '20200910 Welcome to HTTP page.',
      reverse_Domain      => 'nginx01.tzygarlicki.com',
      reverse_ListenPort  => 443,
      reverse_IsPermanent => true,
      reverse_Locations   => {
          '/resources' => 'google.es/',
          '/'          => 'wp.pl'
  }
  }
}

