## Compiling an Apache web server

### What are we doing?

We're compiling an Apache web server for a test system.

### Why are we doing this?

In professional use of the web server it’s very often the case that special requirements (security, additional debugging messages, special features from a new patch, etc.) force you to leave behind the distribution packages and quickly create some binaries on your own. In this case it’s important for the infrastructure to be prepared and to already have experience compiling and running your own binaries on production systems. It’s also easier to work with self-compiled Apache in a laboratory-like setup, which is also beneficial in terms of debugging.

### Step 1: Preparing the directory tree for the source code

It’s not all that important where the source code is located. The following is a recommendation based on the [File Hierarchy Standard](http://www.pathname.com/fhs/). The FHS defines the path structure of a Unix system; the structure for all stored files. Note that in the second command `` `whoami` `` evaluates to the username and not root (despite `sudo`).

```bash
$> sudo mkdir /usr/src/apache
$> sudo chown `whoami` /usr/src/apache
$> cd /usr/src/apache
```

### Step 2: Meeting the requirements for apr and apr-util

Since the release of version 2.4, the Apache web server comes without two important libraries that used to be part of the distribution. We now have to install `apr` and `apr-util` ourselves before being able to compile Apache. `apr` is the Apache Portable Runtime library. It adds additional features to the normal set of C libraries typically needed by server software. They include features for managing hash tables and arrays. These libraries aren’t used by the Apache web server alone, but also by other Apache Software Foundation projects, which is why they were removed from Apache’s source code. Like `apr`, `apr-util` is part of the Portable Runtime libraries supplemented by `apr-util`.

Let’s start with _apr_ and download the package.

```bash
$> wget https://www-eu.apache.org/dist/apr/apr-1.7.0.tar.bz2
```

We’ll now download the checksum of the source code file from Apache. We’ll verify the integrity of the source code we downloaded that way. For better security we’ll be using a secure connection for downloading. Without https this verification doesn’t make much sense. Both files, the source code and the small checksum file, should be placed together in `/usr/src/apache`. We can now verify the checksum:


```bash
$> wget https://www.apache.org/dist/apr/apr-1.7.0.tar.bz2.sha256
$> sha256sum --check apr-1.7.0.tar.bz2.sha256
apr-1.7.0.tar.bz2: OK
```

The test should not result in any problems, _OK_. We can now continue with unpacking, pre-configuring and compiling _apr_.

```bash
$> tar -xvjf apr-1.7.0.tar.bz2
$> cd apr-1.7.0
$> ./configure --prefix=/usr/local/apr/
```

After unpacking, we now change to the new directory containing the source code and start _configure_. This configures the compiler. We specify the installation path and _configure_ gathers a variety of information and settings about our system.
Sometimes, a warning about `libtoolT` is printed but it can be ignored.
The configure command frequently complains about missing components. One thing is certain: Without a working compiler we will be unable to compile and it’s configure’s task to check whether everything is assembled correctly.

Things typically missing:

* build-essential
* binutils
* gcc

And once we are at it, let's install everything else we are going to need throughout this and the following tutorials:

* gawk
* libexpat1-dev
* libpcre3-dev
* libssl-dev
* libxml2-dev
* libyajl-dev
* nikto
* ruby
* zlibc
* zlib1g-dev

These are the package names on Debian-based distributions. The packages may have different names elsewhere. 
The absence of these files can be easily rectified by re-installing them using the utilities from your own distribution. Afterwards, run _configure_ again, perhaps re-install something again and eventually the script will run successfully (individual warnings during the _configure_ steps are no big problem. We just need to be sure the script did not die unexpectedly).

Once it runs without a problem, we can assume that the time for compiling has come.

```bash
$> make
```

This takes a moment after which we get the compiled _apr_, which we promptly install.

```bash
$> sudo make install
```

Once this is successful, we'll do the same with _apr-util_.

```bash
$> cd /usr/src/apache

$> wget https://www-eu.apache.org/dist/apr/apr-util-1.6.1.tar.bz2
$> wget https://www.apache.org/dist/apr/apr-util-1.6.1.tar.bz2.sha256
$> sha256sum --check apr-util-1.6.1.tar.bz2.sha256
apr-util-1.6.1.tar.bz2: OK
$> tar -xvjf apr-util-1.6.1.tar.bz2
$> cd apr-util-1.6.1
$> ./configure --prefix=/usr/local/apr/ --with-apr=/usr/local/apr/
$> make
$> sudo make install
```

Once this works in both cases we're ready for the web server itself.

### Step 3: Downloading the source code and verifying the checksum

We’ll now download the program code from the internet. This can be done by downloading it directly from [Apache](https://httpd.apache.org/) in a browser or, to save the Apache Project’s bandwidth, by using wget to get it from a mirror.

```bash
$> cd /usr/src/apache
$> wget https://www-eu.apache.org/dist//httpd/httpd-2.4.39.tar.bz2
```

The compressed source code is approximately 5 MB in size.

We’ll now download the checksum of the source code file from Apache. At least it’s available as a _sha1 checksum_. We’ll again be using a secure connection for better security. Without https this verification doesn’t make much sense.

```bash
$> wget https://www.apache.org/dist/httpd/httpd-2.4.39.tar.bz2.sha256
$> sha256sum --check httpd-2.4.39.tar.bz2.sha256
httpd-2.4.39.tar.bz2: OK
```

### Step 4: Unpacking and configuring the compiler

After verification we can unpack the package.

```bash
$> tar -xvjf httpd-2.4.39.tar.bz2
```

This results in approximately 38 MB.

We now enter the directory and configure the compiler with our entries and with information about our system. Unlike _apr_, our entries are very extensive.

```bash
$> cd httpd-2.4.39
$> ./configure --prefix=/opt/apache-2.4.39  --with-apr=/usr/local/apr/bin/apr-1-config \
   --with-apr-util=/usr/local/apr/bin/apu-1-config \
   --enable-mpms-shared=event \
   --enable-mods-shared=all \
   --enable-nonportable-atomics=yes
```

This is where we define the target directory for the future Apache web server, again compiling in compliance with the _FHS_. Following this, there are two options for linking the two libraries installed as a precondition. We use `--enable-mpms-shared` to select a process model for the server. Simply put, this is like an engine type: gasoline (petrol) or diesel. In our case, `event`, `worker`, `prefork` and a few experimental engines are available. In this case we’ll take the `event` model, which is the new standard in 2.4 and has significantly better performance over the other architectures. In the 2.0 and 2.2 version lines there was significantly more to consider besides performance, but this set of problems has been significantly defused since 2.4 and it’s best for us to continue with `event`. More information about the different process models (_MPMs_) is available from the Apache Project.

We then define that we want all (_all_) modules to be compiled. Of note here is that _all_ does not really mean all. For historical reasons _all_ means only all of the core modules, of which there are quite a few. The _shared_ keyword indicates that we would like to have the modules compiled separately in order to then be able to link them as optional modules. And lastly, `enable-nonportable-atomics` is a compiler flag which instructs the compiler to use special options which are available only on modern x86 processors and have a favorable impact on performance.

When executing the _configure_ command for the web server, it may be necessary to install additional packages. However, if you have installed all those named in the second step, you should be covered.

### Step 5: Compiling

Once _configure_ is completed, we are ready for the compiler. Nothing should go wrong any longer at this point.

```bash
$> make
```

This takes some time and 38 MB becomes just under 100 MB.

### Step 6: Installing

When compiling is successful, we then install the Apache web server we built ourselves. Installation must be performed by the super user. But right afterwards we’ll see how we can again take ownership of the web server. This is much more practical for a test system.

```bash
$> sudo make install
```

Installation may also take some time.

```bash
$> sudo chown -R `whoami` /opt/apache-2.4.39
```

And now for a trick: If you work professionally with Apache then you often have several different versions on the test server. Different versions, different patches, other modules, etc. result in tedious and long pathnames with version numbers and other descriptions. To ease things, I create a soft link from `/apache` to the current Apache web server when I switch to a new version. Care must be given that we and not the root user are the owners of the soft link (this is important in configuring the server).

```bash
$> sudo ln -s /opt/apache-2.4.39 /apache
$> sudo chown `whoami` --no-dereference /apache
$> cd /apache
```

Our web server now has a pathname clearly describing it by version number. We will however simply use `/apache` for access. This makes work easier.

### Step 7: Starting

Now let’s see if our server will start up. For the moment, this again has to be done by the super user:

```bash
$> sudo ./bin/httpd -X
```

Another trick for test operation: Apache is actually a daemon running as a background process. However, for simple tests this can be quite bothersome, because we have to continually start, stop, reload and otherwise manipulate the daemon. The -X option tells Apache that it can do without the daemon and start as a single process/thread in the foreground. This also simplifies the work.

There is likely to be a warning when starting:

```bash
AH00558: httpd: Could not reliably determine the server's fully qualified domain name, using …
127.0.1.1. Set the 'ServerName' directive globally to suppress this message
```

This is unimportant and we can ignore the warning for the time being.

### Step 8: Trying it out

The engine is running. But is it also working? Time for the function test: We access Apache by entering the following URL in our browser:

[http://127.0.0.1/index.html](http://127.0.0.1/index.html)

We then expect the following:

![Screenshot: It works!](https://www.netnea.com/files/apache-tutorial-1-screenshot-it-works.png)

Apache shows the first signs of life in the browser.

Fantastic! Goal achieved: The self-compiled Apache is running.

Return to the shell and stop the server via CTRL-C.

### Step 9 (Goodie): Inspecting the binaries and the modules

Before completing the tutorial, we’d like to take a closer look at the server. Let’s open the engine compartment and take a peek inside. We can get information about our binary as follows:

```bash
$> sudo ./bin/httpd -V
```

```bash
Server version: Apache/2.4.39 (Unix)
Server built:   May 12 2019 13:32:29
Server's Module Magic Number: 20120211:83
Server loaded:  APR 1.7.0, APR-UTIL 1.6.1
Compiled using: APR 1.7.0, APR-UTIL 1.6.1
Architecture:   64-bit
Server MPM
Server compiled with....
 -D APR_HAS_SENDFILE
 -D APR_HAS_MMAP
 -D APR_HAVE_IPV6 (IPv4-mapped addresses enabled)
 -D APR_USE_SYSVSEM_SERIALIZE
 -D APR_USE_PTHREAD_SERIALIZE
 -D SINGLE_LISTEN_UNSERIALIZED_ACCEPT
 -D APR_HAS_OTHER_CHILD
 -D AP_HAVE_RELIABLE_PIPED_LOGS
 -D DYNAMIC_MODULE_LIMIT=256
 -D HTTPD_ROOT="/opt/apache-2.4.39"
 -D SUEXEC_BIN="/opt/apache-2.4.39/bin/suexec"
 -D DEFAULT_PIDLOG="logs/httpd.pid"
 -D DEFAULT_SCOREBOARD="logs/apache_runtime_status"
 -D DEFAULT_ERRORLOG="logs/error_log"
 -D AP_TYPES_CONFIG_FILE="conf/mime.types"
 -D SERVER_CONFIG_FILE="conf/httpd.conf"
```

Because we specified the version when we compiled, `apr` is mentioned and the `event` _MPM_ appears further below. Incidentally, at the very bottom we see a reference to the web server’s default configuration file and a bit above this the path we can use to find the default _error_log_.

You can however get even more information from the system and inquire about the modules compiled firmly into the server.

```bash
$> sudo ./bin/httpd -l
```

```bash
Compiled in modules:
  core.c
  mod_so.c
  http_core.c
```

This and the information above can be helpful for debugging and useful when submitting bug reports. These are typically the first questions that the developer asks.

The binary itself (`/apache/bin/httpd`) is approx. 2.0 MB in size and the list of modules appears as follows:

```bash
$> ls -lh modules
```

```bash
total 8.8M
-rw-r--r-- 1 myuser root    14K Mar  5 21:09 httpd.exp
-rwxr-xr-x 1 myuser root    36K Mar  5 21:16 mod_access_compat.so
-rwxr-xr-x 1 myuser root    34K Mar  5 21:17 mod_actions.so
-rwxr-xr-x 1 myuser root    49K Mar  5 21:17 mod_alias.so
-rwxr-xr-x 1 myuser root    31K Mar  5 21:17 mod_allowmethods.so
-rwxr-xr-x 1 myuser root    30K Mar  5 21:17 mod_asis.so
-rwxr-xr-x 1 myuser root    47K Mar  5 21:16 mod_auth_basic.so
-rwxr-xr-x 1 myuser root   102K Mar  5 21:16 mod_auth_digest.so
-rwxr-xr-x 1 myuser root    79K Mar  5 21:16 mod_auth_form.so
-rwxr-xr-x 1 myuser root    30K Mar  5 21:16 mod_authn_anon.so
-rwxr-xr-x 1 myuser root    39K Mar  5 21:16 mod_authn_core.so
-rwxr-xr-x 1 myuser root    43K Mar  5 21:16 mod_authn_dbd.so
-rwxr-xr-x 1 myuser root    33K Mar  5 21:16 mod_authn_dbm.so
-rwxr-xr-x 1 myuser root    33K Mar  5 21:16 mod_authn_file.so
-rwxr-xr-x 1 myuser root    54K Mar  5 21:16 mod_authn_socache.so
-rwxr-xr-x 1 myuser root    70K Mar  5 21:16 mod_authz_core.so
-rwxr-xr-x 1 myuser root    46K Mar  5 21:16 mod_authz_dbd.so
-rwxr-xr-x 1 myuser root    37K Mar  5 21:16 mod_authz_dbm.so
-rwxr-xr-x 1 myuser root    41K Mar  5 21:16 mod_authz_groupfile.so
-rwxr-xr-x 1 myuser root    37K Mar  5 21:16 mod_authz_host.so
-rwxr-xr-x 1 myuser root    31K Mar  5 21:16 mod_authz_owner.so
-rwxr-xr-x 1 myuser root    31K Mar  5 21:16 mod_authz_user.so
-rwxr-xr-x 1 myuser root   129K Mar  5 21:17 mod_autoindex.so
-rwxr-xr-x 1 myuser root    35K Mar  5 21:17 mod_buffer.so
-rwxr-xr-x 1 myuser root   103K Mar  5 21:17 mod_cache_disk.so
-rwxr-xr-x 1 myuser root   229K Mar  5 21:17 mod_cache.so
-rwxr-xr-x 1 myuser root   108K Mar  5 21:17 mod_cache_socache.so
-rwxr-xr-x 1 myuser root   118K Mar  5 21:17 mod_cgid.so
-rwxr-xr-x 1 myuser root    68K Mar  5 21:17 mod_charset_lite.so
-rwxr-xr-x 1 myuser root    33K Mar  5 21:17 mod_data.so
-rwxr-xr-x 1 myuser root   221K Mar  5 21:17 mod_dav_fs.so
-rwxr-xr-x 1 myuser root    83K Mar  5 21:17 mod_dav_lock.so
-rwxr-xr-x 1 myuser root   395K Mar  5 21:17 mod_dav.so
-rwxr-xr-x 1 myuser root    71K Mar  5 21:17 mod_dbd.so
-rwxr-xr-x 1 myuser root   100K Mar  5 21:17 mod_deflate.so
-rwxr-xr-x 1 myuser root    36K Mar  5 21:17 mod_dialup.so
-rwxr-xr-x 1 myuser root    37K Mar  5 21:17 mod_dir.so
-rwxr-xr-x 1 myuser root    33K Mar  5 21:17 mod_dumpio.so
-rwxr-xr-x 1 myuser root    34K Mar  5 21:17 mod_echo.so
-rwxr-xr-x 1 myuser root    32K Mar  5 21:17 mod_env.so
-rwxr-xr-x 1 myuser root    44K Mar  5 21:17 mod_expires.so
-rwxr-xr-x 1 myuser root    74K Mar  5 21:17 mod_ext_filter.so
-rwxr-xr-x 1 myuser root    42K Mar  5 21:17 mod_file_cache.so
-rwxr-xr-x 1 myuser root    62K Mar  5 21:17 mod_filter.so
-rwxr-xr-x 1 myuser root    73K Mar  5 21:17 mod_headers.so
-rwxr-xr-x 1 myuser root    30K Mar  5 21:17 mod_heartbeat.so
-rwxr-xr-x 1 myuser root    79K Mar  5 21:17 mod_heartmonitor.so
-rwxr-xr-x 1 myuser root   163K Mar  5 21:17 mod_include.so
-rwxr-xr-x 1 myuser root    85K Mar  5 21:17 mod_info.so
-rwxr-xr-x 1 myuser root    35K Mar  5 21:17 mod_lbmethod_bybusyness.so
-rwxr-xr-x 1 myuser root    35K Mar  5 21:17 mod_lbmethod_byrequests.so
-rwxr-xr-x 1 myuser root    35K Mar  5 21:17 mod_lbmethod_bytraffic.so
-rwxr-xr-x 1 myuser root    52K Mar  5 21:17 mod_lbmethod_heartbeat.so
-rwxr-xr-x 1 myuser root   103K Mar  5 21:17 mod_log_config.so
-rwxr-xr-x 1 myuser root    43K Mar  5 21:17 mod_log_debug.so
-rwxr-xr-x 1 myuser root    37K Mar  5 21:17 mod_log_forensic.so
-rwxr-xr-x 1 myuser root    35K Mar  5 21:17 mod_logio.so
-rwxr-xr-x 1 myuser root   467K Mar  5 21:17 mod_lua.so
-rwxr-xr-x 1 myuser root    56K Mar  5 21:17 mod_macro.so
-rwxr-xr-x 1 myuser root    88K Mar  5 21:17 mod_mime_magic.so
-rwxr-xr-x 1 myuser root    60K Mar  5 21:17 mod_mime.so
-rwxr-xr-x 1 myuser root   184K Mar  5 21:16 mod_mpm_event.so
-rwxr-xr-x 1 myuser root   136K Mar  5 21:16 mod_mpm_worker.so
-rwxr-xr-x 1 myuser root   117K Mar  5 21:17 mod_negotiation.so
-rwxr-xr-x 1 myuser root   198K Mar  5 21:17 mod_proxy_ajp.so
-rwxr-xr-x 1 myuser root   139K Mar  5 21:17 mod_proxy_balancer.so
-rwxr-xr-x 1 myuser root    59K Mar  5 21:17 mod_proxy_connect.so
-rwxr-xr-x 1 myuser root    40K Mar  5 21:17 mod_proxy_express.so
-rwxr-xr-x 1 myuser root    77K Mar  5 21:17 mod_proxy_fcgi.so
-rwxr-xr-x 1 myuser root    40K Mar  5 21:17 mod_proxy_fdpass.so
-rwxr-xr-x 1 myuser root   131K Mar  5 21:17 mod_proxy_ftp.so
-rwxr-xr-x 1 myuser root   114K Mar  5 21:17 mod_proxy_html.so
-rwxr-xr-x 1 myuser root   121K Mar  5 21:17 mod_proxy_http.so
-rwxr-xr-x 1 myuser root    66K Mar  5 21:17 mod_proxy_scgi.so
-rwxr-xr-x 1 myuser root   357K Mar  5 21:17 mod_proxy.so
-rwxr-xr-x 1 myuser root    59K Mar  5 21:17 mod_proxy_wstunnel.so
-rwxr-xr-x 1 myuser root    33K Mar  5 21:17 mod_ratelimit.so
-rwxr-xr-x 1 myuser root    34K Mar  5 21:17 mod_reflector.so
-rwxr-xr-x 1 myuser root    41K Mar  5 21:17 mod_remoteip.so
-rwxr-xr-x 1 myuser root    48K Mar  5 21:17 mod_reqtimeout.so
-rwxr-xr-x 1 myuser root    40K Mar  5 21:17 mod_request.so
-rwxr-xr-x 1 myuser root   210K Mar  5 21:17 mod_rewrite.so
-rwxr-xr-x 1 myuser root   144K Mar  5 21:17 mod_sed.so
-rwxr-xr-x 1 myuser root    35K Mar  5 21:17 mod_session_cookie.so
-rwxr-xr-x 1 myuser root    53K Mar  5 21:17 mod_session_dbd.so
-rwxr-xr-x 1 myuser root    61K Mar  5 21:17 mod_session.so
-rwxr-xr-x 1 myuser root    47K Mar  5 21:17 mod_setenvif.so
-rwxr-xr-x 1 myuser root    32K Mar  5 21:17 mod_slotmem_plain.so
-rwxr-xr-x 1 myuser root    59K Mar  5 21:17 mod_slotmem_shm.so
-rwxr-xr-x 1 myuser root    52K Mar  5 21:17 mod_socache_dbm.so
-rwxr-xr-x 1 myuser root    40K Mar  5 21:17 mod_socache_memcache.so
-rwxr-xr-x 1 myuser root    82K Mar  5 21:17 mod_socache_shmcb.so
-rwxr-xr-x 1 myuser root    43K Mar  5 21:17 mod_speling.so
-rwxr-xr-x 1 myuser root   897K Mar  5 21:17 mod_ssl.so
-rwxr-xr-x 1 myuser root    80K Mar  5 21:17 mod_status.so
-rwxr-xr-x 1 myuser root    48K Mar  5 21:17 mod_substitute.so
-rwxr-xr-x 1 myuser root    35K Mar  5 21:17 mod_unique_id.so
-rwxr-xr-x 1 myuser root    37K Mar  5 21:17 mod_unixd.so
-rwxr-xr-x 1 myuser root    34K Mar  5 21:17 mod_userdir.so
-rwxr-xr-x 1 myuser root    44K Mar  5 21:17 mod_usertrack.so
-rwxr-xr-x 1 myuser root    27K Mar  5 21:17 mod_version.so
-rwxr-xr-x 1 myuser root    40K Mar  5 21:17 mod_vhost_alias.so
-rwxr-xr-x 1 myuser root    54K Mar  5 21:17 mod_watchdog.so
-rwxr-xr-x 1 myuser root    69K Mar  5 21:17 mod_xml2enc.so
```

These are all of the modules distributed along with the server by Apache and we are well aware that we selected the _all_ option for the modules to compile. Additional modules are available from third parties. We don’t need all of these modules, but there are some you'll almost always want to have: They are ready to be included.

### References
- Apache: [https://httpd.apache.org](https://httpd.apache.org)
- File Hierarchy Standard: [http://www.pathname.com/fhs/](http://www.pathname.com/fhs/)
- Apache ./configure documentation: [https://httpd.apache.org/docs/trunk/programs/configure.html](https://httpd.apache.org/docs/trunk/programs/configure.html)


### License / Copying / Further use

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.


