# Description
* It creates a virtual host with a reverse proxy to redirect requests for selected domain to a given IP address. Also, it is able to redirect each location to different address.
* It creates another virtual host to proxy and to log HTTP requests going from the internal network to the Internet
  * It has a simple curl check that checks the proxy server health

# Setup
The following configuration is enough to run the nginx with the default parameters values:
```
node 'lemp01' {
  class { 'nginx': }
}
```

* The current nginx configuration might be overwritten
* Make sure that there is not another services listening on the same ports

# Usage
All the parameters are optional.

The default parameter values are:
```
String  $proxy_Resolver      = '8.8.8.8',
String  $proxy_Allow         = '10.0.0.0/8',
String  $proxy_AccessLog     = '/var/log/nginx/access_forwardproxy.log',
Integer $proxy_ListenPort    = 8080,
String  $proxy_TestWeb       = 'web01.tzygarlicki.com',
String  $proxy_TestString    = '20200910 Welcome to HTTP page.',
String  $reverse_Domain      = 'domain.com',
Integer $reverse_ListenPort  = 443,
Hash    $reverse_Locations   = {
  '/resources' => '20.20.20.20/',
  '/'          => '10.10.10.10'
}
```
* **proxy_** prefix - makes reference to the 'proxy' virtual host
  * **$proxy_Resolver** - DNS used by Nginx
  * **$proxy_Allow** - allow to use the proxy only from the given network. Use the CIDR notation format (example above)
  * **$proxy_AccessLog** - path to access log where the nginx logs the time. The module does not check if the path exists.
  * **$proxy_ListenPort** - sets the Listen nginx directive
  * **$proxy_TestWeb** - sets the web URL where the module connects in order to check the proxy health
  * **$proxy_TestString** - sets the string that must appear at least once on test web in order to pass the health check
* **redirect_** prefix - makes reference to the reverse virtual host
  *  **$reverse_Domain** - sets server_name nginx directive
  *  **$reverse_ListenPort** -  sets the Listen nginx directive
  *  **$reverse_Locations** - list of locations and destinations. Each key-pair value sets a Listen directive in the VH conf file

## Working example
```
node 'lemp01' {
  class { 'nginx':
    proxy_Resolver     => '8.8.8.8',
    proxy_Allow        => '10.0.0.0/8',
    proxy_AccessLog    => '/var/log/nginx/access_forwardproxy.log',
    proxy_ListenPort   => 8080,
    proxy_TestWeb      => 'web01.tzygarlicki.com',
    proxy_TestString   => '20200910 Welcome to HTTP page.',
    reverse_Domain     => 'nginx01.tzygarlicki.com',
    reverse_ListenPort => 443,
    reverse_Locations  => {
      '/resources' => 'duckduckgo.com/',
      '/'          => 'wp.pl'
    }
  }
}
```

# Limitations
**This is a beta version.**
Use it on the preproduction environments only.

# Development
The following improvements are possible:
* [Important] The certificate key in the files is readable by others. This file mode permits to read the file by the puppet service user, but it is a security risk.
* The string **proxy_Allow** parameter should be changed into an array, so it will be possible to _allow_ more than one networks
* Using the **nagios_command** resource type instead of bash one-liner might be better (<https://puppet.com/docs/puppet/5.5/types/nagios_command.html>)
* Test and develop it for other Ubuntu versions, specially the 20.04 LTS
* Test and develop it for other distributions, specially for Debian and Red Hat/CentOS,