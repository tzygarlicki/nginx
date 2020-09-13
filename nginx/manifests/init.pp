class nginx (
  String  $proxy_Resolver      = '8.8.8.8',
  String  $proxy_Allow         = '10.0.0.0/8',
  String  $proxy_AccessLog     = '/var/log/nginx/access_forwardproxy.log',
  Integer $proxy_ListenPort    = 8080,
  String  $proxy_TestWeb       = 'web01.tzygarlicki.com',
  String  $proxy_TestString    = '20200910 Welcome to HTTP page.',
  String  $reverse_Domain      = 'domain.com',
  Integer $reverse_ListenPort  = 80,
  Hash    $reverse_Locations   = { 
    '/resources' => '20.20.20.20/',
    '/'          => '10.10.10.10'
  }
) {
  contain nginx::install
  contain nginx::config
  contain nginx::service

  Class['::nginx::install']
  -> Class['::nginx::config']
  ~> Class['::nginx::service']
}

