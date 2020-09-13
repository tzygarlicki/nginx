# How did I come up with the solution

* Windows 10
* Firefox 79
* Caret 4.0.0 - Markdown editor
* Terminus 1.0.105 - SSH client for Windows
* <http://digitalocean.com> - VPS provider
* <http://ionos.es> - domain name registrar

This document describes the steps that I took to come up with the solution in the chronological order.

I developed the nginx module from the scratch, however I had a look at other modules from Puppet Forge (<https://forge.puppet.com/>).

## Desired configuration
Before creating the Puppet module, I need to have a working machine with the desired configuration. This way, I will be able to edit and test the configuration before creating the final module.

| nginx01        | nginx01.tzygarlicki.com |
| -------------- | ----------------------- |
| Localization   | Frankfurt, Germany      |
| Cost           | 5$/month                |
| OS             | Ubuntu 18.04            |
| RAM            | 1 GB                    |
| Storage        | 25 GB                   |
| Credentials    | -                       |
| Public IP      | 167.71.53.76            |  
| Private IP     | 10.135.0.2              |

When the VPS was created, the nginx, MySQL and PHP came installed by default.


## Reverse proxy for 'domain.com'
    
My goal is to create a proxy to redirect following requests:

| Request                       | Redirect to     |
| ----------------------------- | --------------- |
| https://domain.com            | 10.10.10.10     |
| https://domain.com/resource   | 20.20.20.20     |

### /etc/nginx/sites-available/forward_proxy.conf
```
server {
    listen 443;
    
    server_name nginx01.tzygarlicki.com;
    
    ssl_certificate /etc/nginx/ssl/cert.crt;
    ssl_certificate_key /etc/nginx/ssl/cert.key;
    ssl on;
    ssl_session_cache builtin:1000 shared:SSL:10m;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
    ssl_prefer_server_ciphers on;

    access_log /var/log/nginx/access.log;

          location /resources {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://duckduckgo.com/;
        proxy_read_timeout 90;
        }
          location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://wp.pl;
        proxy_read_timeout 90;
        }
    }
```
## Forward HTTP proxy
My goal is to *create a forward proxy to log HTTP requests going from the internal network to the Internet including: request protocol, remote IP and time take to serve the request.*

I don't have any information about the local network, so for the example needs it will be **10.135.0.0/16**

The final configuration should be the following:

###  /etc/nginx/conf.d/logging.conf
The **timing** format that will be used in the next file.
```
log_format timing '[$time_local] $scheme - $remote_addr - $request_time';
```

### /etc/nginx/sites-available/forward_proxy.conf
```
server {
    listen 8080;

    allow 10.135.0.0/16;
    allow 127.0.0.1;
    deny  all;

    location / {
        resolver   8.8.8.8;
        proxy_pass http://$http_host$uri$is_args$args;
        access_log /var/log/nginx/access_forwardproxy.log timing;
    }
}
```

* The server will listen on **80** port only,
* I added the **allow** and **deny** directives, because of security reasons,
* The log will be saved into the **/var/log/nginx/forward_proxy/access.log** file
* The log file will have the **timing** format

### Testing
```
root@puppet01:~# curl -x 10.135.0.2:80 "http://web01.tzygarlicki.com"
20200910 Welcome to HTTP page.
```
It works!

```
root@puppet01:~# curl -x nginx01.tzygarlicki.com:80 "http://web01.tzygarlicki.com" -I
HTTP/1.1 403 Forbidden
Server: nginx/1.14.0 (Ubuntu)
Date: Thu, 10 Sep 2020 21:08:34 GMT
Content-Type: text/html
Content-Length: 178
Connection: keep-alive
```
I get the **403** status code, because of the **deny all** directive, which is correct, because the **nginx01.tzygarlicki.com** domain name resolves an IP out of **10.135.0.0/16** range:
```
root@puppet01:~# nslookup nginx01.tzygarlicki.com
Server:         127.0.0.53
Address:        127.0.0.53#53

Non-authoritative answer:
Name:   nginx01.tzygarlicki.com
Address: 167.71.53.76
```
##  Puppet Server
| puppet01       | puppet01.tzygarlicki.com |
| -------------- | ------------------------ |
| Localization   | Frankfurt, Germany       |
| Cost           | 10$/month                |
| OS             | Ubuntu 18.04             |
| RAM            | 2 GB                     |
| Storage        | 50 GB                    |
| Credentials    | -                        |
| Public IP      | 164.90.220.231           |  
| Private IP     | 10.135.0.3               |

All the installation and configuration steps were taken according to the official documentation at <https://puppet.com/docs/puppet/6.18/puppet_index.html>


#  Puppet module
I followed the official documentation at:
<https://puppet.com/docs/puppet/5.5/puppet_index.html>

The **nginx** (init.pp file) contains the following classes:
* nginx::install
* nginx::config
* nginx::service

## nginx::install
Ensures that **nginx** and **curl** packages are installed.
The module uses the last one to check the proxy health in the **nginx::service** class.

## nginx::config
### /etc/nginx/nginx.conf
* Uses the **nginx/nginx.conf.erb** file as a template.
* This template is the original nginx 1.14.0 configuration file, without any parameter.
* Its purpose is to ensure that the **include /etc/nginx/conf.d/*.conf;** directive exists.
* I could have used the file resource instead, but using a template makes it faster to add parameters in the future

### /etc/ngnix/ssl/cert.crt, /etc/ngnix/ssl/cert.key
* Copies the ssl files to the node
* Sets an appropiate mode, owner and owner group

### /etc/nginx/conf.d/logging.conf
* Uses the **nginx/logging.conf.erb** as a template.
* The ERB file contains the **timing** log format
* Based on: <https://nginx.org/en/docs/http/ngx_http_log_module.html>

### /etc/nginx/sites-available/proxy.conf
* It sets all the **proxy_** prefixed parameters to configure the virtual host

### /etc/nginx/sites-available/${nginx::reverse_Domain}.conf
* Its name depends on the **reverse_Domain** parameter 
* It sets all the **reverse_** prefixed parameters to configure the  virtual host

## nginx::service
* Ensures the service is working
* Performs a health check
  * It uses bash and curl
  * Using the **nagios_command** resource type instead of bash one-liner might be better (<https://puppet.com/docs/puppet/5.5/types/nagios_command.html>)

# Testing
## nginx01
The **node01** VPS comes with the Nginx preinstalled.
I tested all the functionalities during the module development on the **node01** VM. 

Despite all the tests finished successfully, I need to test it again on new, clean machine.

## nginx02
| nginx02        | nginx02.tzygarlicki.com |
| -------------- | ----------------------- |
| Localization   | Frankfurt, Germany      |
| Cost           | 5$/month                |
| OS             | Ubuntu 18.04            |
| RAM            | 1 GB                    |
| Storage        | 25 GB                   |
| Credentials    | -                       |
| Public IP      | 165.22.26.188           |  
| Private IP     | 10.135.0.4              |

The machine is in the **tzygarlicki.com** domain, however I modified the **/etc/hosts**, so the agent will talk with the master over the private network.

In summary, I executed only the following commands:
```
root@nginx02:~# history
    1  hostname
    2  vim /etc/hosts
    3  wget https://apt.puppetlabs.com/puppet5-release-bionic.deb
    4  dpkg -i puppet5-release-bionic.deb
    5  apt update
    6  puppet
    7  export PATH=/opt/puppetlabs/bin:$PATH
    8  apt-get install puppet-agent
    9  puppet config set server puppet01 --section main
   10  /opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true
   11  /opt/puppetlabs/bin/puppet agent --test
   12  history
root@nginx02:~# 
```

Also, I added the **nginx02** node definition on Puppet server:

```
node 'nginx02' {
  class { 'nginx':
    proxy_Resolver     => '8.8.8.8',
    proxy_Allow        => '10.0.0.0/8',
    proxy_AccessLog    => '/var/log/nginx/access_forwardproxy.log',
    proxy_ListenPort   => 8080,
    proxy_TestWeb      => 'web01.tzygarlicki.com',
    proxy_TestString   => '20200910 Welcome to HTTP page.',
    reverse_Domain     => 'nginx02.tzygarlicki.com',
    reverse_ListenPort => 443,
    reverse_Locations  => {
      '/resources' => 'duckduckgo.com/',
      '/'          => 'wp.pl'
    }
  }
}
```

### Tests
```
root@nginx02:~# netstat -putan | grep nginx
tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN      13799/nginx: master 
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      13799/nginx: master 
tcp6       0      0 :::80                   :::*                    LISTEN      13799/nginx: master 
udp        0      0 165.22.26.188:36606     8.8.8.8:53              ESTABLISHED 13803/nginx: worker 
```

```
root@nginx02:/etc/nginx/sites-enabled# ls -lash
total 8.0K
4.0K drwxr-xr-x 2 root root 4.0K Sep 12 22:01 .
4.0K drwxr-xr-x 8 root root 4.0K Sep 12 22:01 ..
   0 lrwxrwxrwx 1 root root   34 Sep 12 22:00 default -> /etc/nginx/sites-available/default
   0 lrwxrwxrwx 1 root root   55 Sep 12 22:01 nginx01.tzygarlicki.com.conf -> /etc/nginx/sites-available/nginx01.tzygarlicki.com.conf
   0 lrwxrwxrwx 1 root root   37 Sep 12 22:01 proxy.conf -> /etc/nginx/sites-available/proxy.conf
```

Everything seems to be OK, but I worry about the **default** symlink.
Before continuing the tests, I will modify the module in order to delete the symlink.

```
class nginx::config
{
  file { '/etc/nginx/sites-enabled/default':
    ensure => absent,
  }
...
```
The **default** file disappeared.

#### Forward proxy testing
```
root@nginx02:/etc/nginx/sites-enabled# date; curl -L -x 10.135.0.4:8080 "http://web01.tzygarlicki.com" ; tail -n1 /var/log/nginx/access_forwardproxy.log
Sat Sep 12 22:44:33 UTC 2020
20200910 Welcome to HTTP page.  

[12/Sep/2020:22:44:33 +0000] http - 10.135.0.4 - 0.010
```

#### Reverse proxy test
The first test consists of requesting the **nginx02.tzygarlicki.com** and **nginx02.tzygarlicki.com/resources** from the Firefox on the public PC that is not related to the nodes network. The test is approved.

The second test is the same as the first one, but instead of using a browser, I will use **curl**:

```
tom@v2201911107843102006:~$ curl -k -L -I "https://nginx02.tzygarlicki.com"
HTTP/1.1 301 Moved Permanently
Server: nginx/1.14.0 (Ubuntu)
Date: Sun, 13 Sep 2020 02:12:56 GMT
Content-Type: text/html
Content-Length: 162
Connection: keep-alive
Location: http://www.wp.pl/

HTTP/1.1 301 Moved Permanently
Server: nginx
Date: Sun, 13 Sep 2020 02:12:56 GMT
Content-Type: text/html
Content-Length: 162
Connection: keep-alive
Location: https://www.wp.pl/

HTTP/2 200 
server: nginx
date: Sun, 13 Sep 2020 02:12:56 GMT
content-type: text/html; charset=utf-8
content-length: 0
x-ab-test: __notest
x-request-id: 6861ab75e7f4e06f81819ef9b37a3516
set-cookie: STabid=6861ab75e7f4e06f81819ef9b37a3516:1599963176.771:v1; path=/; Max-Age=31536000
set-cookie: STabnoid=1; path=/
x-op-id-all: 5a2s
accept-ch: device-memory, dpr, width, viewport-width, rtt, downlink, ect
accept-ch-lifetime: 604800
```

```
tom@v2201911107843102006:~$ curl -k -L -I "https://nginx02.tzygarlicki.com/resources"
HTTP/1.1 301 Moved Permanently
Server: nginx/1.14.0 (Ubuntu)
Date: Sun, 13 Sep 2020 02:13:45 GMT
Content-Type: text/html
Content-Length: 162
Connection: keep-alive
Location: https://duckduckgo.com/
X-Frame-Options: SAMEORIGIN
Content-Security-Policy: default-src https: blob: data: 'unsafe-inline' 'unsafe-eval'; frame-ancestors 'self'
X-XSS-Protection: 1;mode=block
X-Content-Type-Options: nosniff
Referrer-Policy: origin
Expect-CT: max-age=0
Expires: Mon, 13 Sep 2021 02:13:45 GMT
Cache-Control: max-age=31536000
X-DuckDuckGo-Locale: en_US

HTTP/2 200 
server: nginx
date: Sun, 13 Sep 2020 02:13:45 GMT
content-type: text/html; charset=UTF-8
content-length: 5763
vary: Accept-Encoding
etag: "5f5d231a-1683"
strict-transport-security: max-age=31536000
x-frame-options: SAMEORIGIN
content-security-policy: default-src https: blob: data: 'unsafe-inline' 'unsafe-eval'; frame-ancestors 'self'
x-xss-protection: 1;mode=block
x-content-type-options: nosniff
referrer-policy: origin
expect-ct: max-age=0
expires: Sun, 13 Sep 2020 02:13:44 GMT
cache-control: no-cache
accept-ranges: bytes
```