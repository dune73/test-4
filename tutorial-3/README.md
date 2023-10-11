## Setting up an Apache/PHP application server

### What are we doing?

We are setting up an Apache/PHP application server using the minimal number of modules necessary.

### Why are we doing this?

A bare bones Apache server is suitable for delivering static files. More complex applications rely on dynamic content. This requires an extension of the server. A very fast and secure application server can be implemented using _suEXEC_, an external _FastCGI daemon_ and _PHP_. This is by far not the only option and also likely not the most widespread one in a corporate environment. But is a very simple architecture perfectly suited for a test system.

### Requirements

* An Apache web server, ideally one created using the file structure shown in [Tutorial 1 (Compiling an Apache web server)](https://www.netnea.com/cms/apache-tutorial-1_compiling-apache/).
* Understanding of the minimal configuration in [Tutorial 2 (Configuring a minimal Apache server)](http://www.netnea.com/cms/apache-tutorial-2_minimal-apache-configuration).


### Step 1: Configuring Apache

We’ll configure the web server to start off with, aware of the fact that it is not yet capable of running in this configuration. Based on the minimal web server described in Tutorial 2, we’ll configure a very simple application server in the *conf/httpd.conf_fastcgid* file.

```bash
ServerName              localhost
ServerAdmin             root@localhost
ServerRoot              /apache
User                    www-data
Group                   www-data

ServerTokens            Prod
UseCanonicalName        On
TraceEnable             Off

Timeout                 10
MaxRequestWorkers       100

Listen                  127.0.0.1:80

LoadModule              mpm_event_module        modules/mod_mpm_event.so
LoadModule              unixd_module            modules/mod_unixd.so

LoadModule              log_config_module       modules/mod_log_config.so
LoadModule              mime_module             modules/mod_mime.so

LoadModule              authn_core_module       modules/mod_authn_core.so
LoadModule              authz_core_module       modules/mod_authz_core.so

LoadModule              suexec_module           modules/mod_suexec.so
LoadModule              fcgid_module            modules/mod_fcgid.so

ErrorLogFormat          "[%{cu}t] [%-m:%-l] %-a %-L %M"
LogFormat               "%h %l %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \
\"%{Referer}i\" \"%{User-Agent}i\"" combined

LogLevel                debug
ErrorLog                logs/error.log
CustomLog               logs/access.log combined

AddHandler              fcgid-script .php

DocumentRoot            /apache/htdocs

<Directory />

        Require all denied

        Options         SymLinksIfOwnerMatch

</Directory>

<VirtualHost 127.0.0.1:80>

      <Directory /apache/htdocs>

        Require all granted

        Options          ExecCGI

        FcgidWrapper      /apache/bin/php-fcgi-starter/php-fcgi-starter .php

      </Directory>

</VirtualHost>
```


I will no longer be discussing the overall configuration, but will instead only be focusing on the differences from Tutorial 2. There are three new modules:
Added to the _suEXEC_ and _FCGI_ modules is the _Mime module_, which enables us to assign the _.php_ file suffix to the _FCGI daemon_. It is assigned using the _AddHandler directive_. 

The _/apache/htdocs_ directory now needs the additional _ExecCGI_ option. And finally, the _FcgidWrapper_. This is the connection between the web server and the _FCGI daemon_ yet to be configured. Once the first request using the _.php_ suffix is received by the web server, the server calls a _wrapper script_, starting the _FCGI daemon_, which from this time on handles the _PHP requests_.

_FastCGI_ is a method for executing dynamic program code from a web server. It is a very fast method which for the most part leaves the server untouched and runs the application on a separate daemon. To increase the speed, _FastCGI_ provides multiple instances of this daemon, allowing requests to be processed without having to wait. In practice, this is a promising gain in performance and, more importantly, an architecture that saves memory, as will be discussed in more detail below.

### Step 2: Compiling Apache with suEXEC support

We now have to compile two missing modules and deploy other components for the _FCGI daemon_. Let’s start with the _suEXEC module_.

An Apache web server was compiled in Tutorial 1. However, although the _--enable-mods-shared=all_ option was used, _suexec_ has not been compiled yet. It seems, the module is so special that it can’t be compiled as a default module, although it is present in the source code.

The web server configured in Tutorial 2 runs as user _www-data_ or, depending on configuration, as any other dedicated user. We would like to further restrict our dynamic application to have the separate daemon run as an additional, separate user that is introduced in one of the next steps. The _suEXEC_ module makes this possible for us. It is not absolutely required. But it adds a bit more security with little extra effort.

Let’s enter the directory with the Apache source code and compile the server once more. 

```bash
$> cd /usr/src/apache/httpd-2.4.54
$> ./configure --prefix=/opt/apache-2.4.54 --enable-mods-shared=all \
   --with-apr=/usr/local/apr/bin/apr-1-config \
   --with-apr-util=/usr/local/apr/bin/apu-1-config --enable-mpms-shared="event" \
   --enable-nonportable-atomics=yes --enable-suexec --with-suexec-caller=www-data \
   --with-suexec-docroot=/opt/apache-2.4.54/bin && make && sudo make install
```

Besides _configure_, which we are familiar with, three options have been added for handling _suexec_. _Enable-suexec_ is self-explanatory, _with-suexec-caller_ we tell the conscientious module that only the user _www-data_ is to be given permission to access the program behind the module. We are after all telling the module where scripts being called are located. For simplicity’s sake let’s use the existing _bin directory_. _suexec_ is however a bit fussy and we are unable to use the symlink. So it will have to be the fully qualified path.

If successfully configured, the command line above will start the compiler and after being successfully concluded will install the newly compiled server.

By the way, if you make a mistake in the configuration above and want to assign _suexec_ different compiler constants, you’ll first have to clean out the compiler environment before compiling again. The new options will otherwise be ignored. We can do this via the _make clean_ command in front of _configure_ or by manually deleting the files _support/suexec_, _support/suexec.lo_ and _support/suexec.o_, which is faster, because the whole web server no longer has to be built from scratch.

### Step 3: Downloading and compiling the FastCGI module

The _FastCGI module_ is managed by Apache. But it is not part of the normal source code for the web server. So, let’s download the source code for the additional module and verify the loaded checksum over an encrypted connection.

```bash
$> cd /usr/src/apache
$> wget http://www.apache.org/dist/httpd/mod_fcgid/mod_fcgid-2.3.9.tar.gz
$> wget https://www.apache.org/dist/httpd/mod_fcgid/mod_fcgid-2.3.9.tar.gz.sha1
$> sha1sum --check mod_fcgid-2.3.9.tar.gz.sha1
```

We again expect an _OK_. When it is correctly returned, it’s time for unpacking, compiling and installing.

```bash
$> tar -xvzf mod_fcgid-2.3.9.tar.gz
$> cd mod_fcgid-2.3.9
$> APXS=/apache/bin/apxs ./configure.apxs
$> make
$> sudo make install
```

The _configure_ command has a slightly different format here, because the _FCGI module_ is a module dependent on Apache. That’s why we are using _APXS_, the _Apache Expansion Tool_, part of the server compiled in Tutorial 1. Unfortunately, _make install_ will partly destroy some of the ownerships we have set. They will have to be adjusted afterwards.

```bash
$> sudo chown `whoami` /apache/conf/httpd.conf
```

The Apache user also needs access to a directory for him to create sockets, enabling communication with the FCGI daemon. We’ll create the directory and transfer ownership to it directly.

```bash
$> sudo mkdir /apache/logs/fcgidsock
$> sudo chown www-data:www-data /apache/logs/fcgidsock
```

### Step 4: Installing and preconfiguring PHP

Up till now we have been compiling all of the software piece by piece. But for the entire PHP stack a limit has been reached. No one should be prevented from compiling PHP on his own, but we are concentrating on the web server here and for this reason will be using this piece of software from the Linux distribution. In Debian/Ubuntu the package we need is _php7.0-cgi_, which comes along with _php7.0-common_.

Properly configuring _PHP_ is a broad topic and I recommend consulting the relevant pages, because an improperly configured installation of _PHP_ may pose a serious security problem. I don’t wish to give you any more information at this point, because it takes us away from our actual topic, which is a simple application server. For operation on the internet, i.e. no longer in a lab-like setup, it is highly recommended to become familiar with the relevant PHP security settings.

### Step 5: Creating the CGI user

Above it has already been discussed that we are planning to start a separate daemon to process _PHP requests_. This daemon should be started via _suexec_ and run as separate user. We create the user as follows:

```bash
$> sudo groupadd fcgi-php
$> sudo useradd -s /bin/false -d /apache/htdocs -m -g fcgi-php fcgi-php
```

It can be expected for a warning to appear concerning the presence of the _/apache/htdocs_ directory. We can ignore it.

### Step 6: Creating a PHP wrapper script

It is normal to use a wrapper script for _PHP_ and _FCGI_ to work together. We already set this up in the Apache configuration above. The web server will invoke only the script, while the script takes care of everything else. We place the script as intended in _/apache/bin/php-fcgi-starter/php-fcgi-starter_. 
The subdirectory isn’t needed, because _suexec_ requires the directory to be owned by the preconfigured user and we don’t want to assign _./bin_ completely to the new user. So, let’s create the subdirectory:

```bash
$> cd /apache/bin
$> sudo mkdir php-fcgi-starter
$> sudo chown fcgi-php:fcgi-php php-fcgi-starter
```

We now have to put a starter script in this directory. Since we have already assigned _fcgi-php_ to the user, the root user will have to create the script. Or be copied by him to this location. Creating a script in a directory that we no longer own is challenging. We’ll solve this with a trick using _cat_ and a _subshell_. Here’s the trick, followed by the script. (Input in _cat_ is ended via CTRL-D).

```bash
$> sudo sh -c "cat > php-fcgi-starter/php-fcgi-starter"
#!/bin/sh
export PHPRC=/etc/php/7.0/cgi/
export PHP_FCGI_MAX_REQUESTS=5000
export PHP_FCGI_CHILDREN=5
exec /usr/lib/cgi-bin/php
```

What are we defining here? We are telling _PHP_ where to find its configuration, setting the maximum number of requests for an _FCGI_ to 5,000 (after which it is replaced by a fresh process), defining the number of process children to 5 and executing PHP at the end.

Now don't forget to assign the script to the _FCGI user_ and make it executable:

```bash
$> sudo chown fcgi-php:fcgi-php php-fcgi-starter/php-fcgi-starter
$> sudo chmod +x php-fcgi-starter/php-fcgi-starter
```

### Step 7: Creating a PHP test page

To finish things off, we should now create a simple _PHP-based_ test page: _/apache/htdocs/info.php_.

```bash
<?php
phpinfo();
?>
```

### Step 8: Trying it out

That was everything. We can now start our web server and try it out.

```bash
$> cd /apache
$> sudo ./bin/httpd -X -f conf/httpd.conf_fastcgid
```

Our test script is available at [http://localhost/info.php](http://localhost/info.php).

![Screenshot: phpinfo()](https://www.netnea.com/files/apache-tutorial-3-screenshot-phpinfo.png)

phpinfo gives you a comprehensive status report in your browser.

If an error message results from starting the server or invoking the URL, the server’s _error log_ or the separate _suexec log_ in _logs/suexec_log_ may prove helpful. Errors are typically related to ownership of and permission to access directories and files.

Here again is a summary of the relevant files and their owners:

```bash
2107985    4 drwxr-xr-x   2 fcgi-php fcgi-php     4096 Jul  2 11:15 bin/php-fcgi-starter/
2107987    4 -rwxr-xr-x   1 fcgi-php fcgi-php      125 Jul  2 11:15 bin/php-fcgi-starter/php-fcgi-starter
2107977   32 -rwsr-xr-x   1 root     root        32146 Jul  2 10:44 bin/suexec
2633547    4 drwxr-xr-x   2 myuser   root         4096 Jul  2 11:16 htdocs/
2633758    4 -rw-r--r--   1 myuser   myuser         20 Jul  2 11:15 htdocs/info.php
2762281    4 drwxr-xr-x   2 www-data www-data     4096 Jul  2 10:46 /apache/logs/fcgidsock/
```

Of note is the _suid bit_ on the _suexec binary_.

### Step 9 (Goodie): A little performance test

Compared to Apache with integrated _PHP_, the application server built here is very high performance. A little performance test can illustrate this. We start our web server in _daemon mode_ and use ApacheBench to put it to the test it with 5 users. The _-l_ option is new. It instructs the tool to ignore deviations in the length of the responses. This is because the page is generated dynamically and the content, as well as its length, will of course be a bit different now and then. We again quit the server following the performance test.

```bash
$> sudo ./bin/httpd -k start -f conf/httpd.conf_fastcgid
$> ./bin/ab -c 5 -n 1000 -l http://localhost/info.php
...
$> sudo ./bin/httpd -k stop -f conf/httpd.conf_fastcgid
```

In most cases _ab_ has the following output:

```bash
This is ApacheBench, Version 2.3 <$Revision: 1663405 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking localhost (be patient)
Completed 100 requests
Completed 200 requests
Completed 300 requests
Completed 400 requests
Completed 500 requests
Completed 600 requests
Completed 700 requests
Completed 800 requests
Completed 900 requests
Completed 1000 requests
Finished 1000 requests


Server Software:        Apache
Server Hostname:        localhost
Server Port:            80

Document Path:          /info.php
Document Length:        Variable

Concurrency Level:      5
Time taken for tests:   2.567 seconds
Complete requests:      1000
Failed requests:        0
Total transferred:      66892443 bytes
HTML transferred:       66739443 bytes
Requests per second:    389.63 [#/sec] (mean)
Time per request:       12.833 [ms] (mean)
Time per request:       2.567 [ms] (mean, across all concurrent requests)
Transfer rate:          25452.57 [Kbytes/sec] received

Connection Times (ms)
              min mean[+/-sd] median  max
Connect:        0    0   0.1      0       1
Processing:     4   13  70.9      7    1147
Waiting:        2   12  70.8      6    1143
Total:          4   13  70.9      7    1147

Percentage of the requests served within a certain time (ms)
  50%      7
  66%      9
  75%     10
  80%     11
  90%     14
  95%     17
  98%     24
  99%     28
 100%   1147 (longest request)

```

That‘s 389 dynamic requests per second. Which is a lot. Especially considering that the result is from a small test computer. On a modern production-size server performance many times this can be achieved.

What’s remarkable isn’t the speed of the system, it’s memory usage. Unlike an application server with integrated _PHP module_, we have separated the _PHP stack_ here. This gives us an Apache web server able to use _Event MPM_. In an integrated setup we would have to use the _Prefork MPM_, which works with memory-intensive server processes and not server threads. And each of these processes would then have to load the _PHP module_, regardless of the fact that most requests are normally attributed to static application components such as images, _CSS_, _JavaScripts_, etc.
On my test system each _Prefork Apache process_, including _PHP_, brings a _resident size_ of 6 MB. An event process with only _4 MB_ means a substantial difference. And outside of this, the number of external _FCGI processes_ will remain significantly smaller.

### References

* Apache: http://httpd.apache.org
* Apache FCGI: http://httpd.apache.org/mod_fcgid
* How2Forge PHP/FCGI: http://www.howtoforge.com/how-to-set-up-apache2-with-mod_fcgid-and-php5-on-ubuntu-10.04


### License / Copying / Further use

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
