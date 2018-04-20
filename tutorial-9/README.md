## Setting up a reverse proxy server

### What are we doing?

We are configuring a reverse proxy protecting access to the application and shielding the application server from the internet. In doing so, we’ll become familiar with several configuration methods and will be working with ModRewrite for the first time.

### Why are we doing this?

A modern application architecture has multiple layers. Only the reverse proxy is exposed to the internet. It conducts a security check on the HTTP payload and forwards the requests found to be good to the application server in the second layer. This in turn is connected to a database server located in yet another layer. This is referred to as a three-tier model. In a staggered defense spanning three levels, the reverse proxy or to be technically correct, the gateway server, provides the first look into the encrypted requests. On the way back it is in turn the last instance in which the responses can be checked one last time.

There are a number of ways for converting an Apache server into a reverse proxy. More importantly, there are multiple ways of communicating with the application server. In this tutorial we will be restricting ourselves to the normal HTTP-based `mod_proxy_http`. We will not be discussing other methods of communication such as FastCGI proxy or AJP here. There are also several ways of getting the proxy process going in Apache. We will start by looking at the normal setup using ProxyPass and will afterwards discuss other options using ModRewrite.

### Requirements

The following is a recommended set of requirements. You do not really need all of these, but if you follow them diligently, I am sure all the examples will work 1:1. If you take a short cut, it will probably need some tweaking with paths and predefined aliases.

* An Apache web server, ideally one created using the file structure shown in [Tutorial 1 (Compiling an Apache web server)](https://www.netnea.com/cms/apache-tutorial-1_compiling-apache/).
* Understanding of the minimal configuration from [Tutorial 2 (Configuring a minimal Apache server)](https://www.netnea.com/cms/apache-tutorial-2_minimal-apache-configuration/).
* An Apache web server with SSL/TLS support as shown in [Tutorial 4 (Configuring an SSL server)](https://www.netnea.com/cms/apache-tutorial-4_configuring-ssl-tls/).
* An Apache web server with extended access log as shown in [Tutorial 5 (Extending and analyzing the access log)](https://www.netnea.com/cms/apache-tutorial-5/apache-tutorial-5_extending-access-log/).
* An Apache web server with ModSecurity as shown in [Tutorial 6 (Embedding ModSecurity)](https://www.netnea.com/cms/apache-tutorial-6/apache-tutorial-6_embedding-modsecurity/).
* An Apache web server with the Core Rule Set, as shown in [Tutorial 7 (Including the Core Rule Set)](https://www.netnea.com/cms/apache-tutorial-7_including-modsecurity-core-rules/)



### Step 1: Preparing the backend

The purpose of a reverse proxy is to shield an application server from direct internet access. As somewhat of a prerequisite for this tutorial, we’ll be needing a backend server like this.
In principle, any HTTP application can be used for such an installation and we could very well use the application server from the third tutorial. However, it seems appropriate for me to demonstrate a very simple approach. We’ll be using the tool `socat` short for SOcket CAt.

```bash
$> socat -vv TCP-LISTEN:8000,bind=127.0.0.1,crlf,reuseaddr,fork SYSTEM:"echo HTTP/1.0 200;\
echo Content-Type\: text/plain; echo; echo 'Server response, port 8000.'"
``` 
 Using this complex command we instruct socat to bind a listener to local port 8000 and to use several echoes to return an HTTP response when a connection occurs. The additional parameters make sure that the listener stays permanently open and error output works.

```bash
$> curl -v http://localhost:8000/
* Hostname was NOT found in DNS cache
*  Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 8000 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost:8000
> Accept: */*
> 
* HTTP 1.0, assume close after body
< HTTP/1.0 200
< Content-Type: text/plain
< 
Server response, port 8000
* Closing connection 0
```

We have set up a backend system with the simplest of means. So easy, that in the future we might come back to this method to verify that a proxy server is working before the real application server is running.

### Step 2: Enabling the proxy module

Several modules are required to use Apache as a proxy server. We compiled them in the first tutorial and can now simply link them.

```bash
LoadModule              proxy_module            modules/mod_proxy.so
LoadModule              proxy_http_module       modules/mod_proxy_http.so
```

The proxying feature set is provided by a basic proxy module and a proxy HTTP module. Proxying actually means receiving a request and forwarding it to another server. In our case we will be defining the backend system from the beginning and then accept requests from different clients for this backend service. It’s a different situation if you set up a proxy server that accepts requests from a group of clients and sends then onward to any server on the internet. This is referred to as a forward proxy. This is useful for when you don’t want to directly expose clients on a corporate network to the internet since the proxy server appears as a client to the servers on the internet.

This mode is also possible in Apache, even if for historical reasons. Alternative software packages offering these features have become well established, e.g. squid. The case is relevant insofar as a faulty configuration may have fatal consequences, particularly if the forward proxy accepts requests from any client and sends them onward to the internet in anonymized form. This is referred to as an open proxy. It’s essential to prevent this since we don’t want to operate Apache in this mode. That requires a directive in the past used to reference the risky default `on` value, but is now correctly predefined as `off`:

```bash
ProxyRequests Off
```

This directive actually means forwarding requests to servers on the internet, even if the name indicates a general setting. As mentioned before, the directive is correctly set for Apache 2.4 and it is only being mentioned here to guard against questions or incorrect settings in the future.

### Step 3: ProxyPass

This brings us to the actual proxying settings: There are many ways for instructing Apache to forward a request to a backend application. We’ll be looking at each option in turn. The most common way of proxying requests is based on the ProxyPass directive. It is used as follows:

```bash
ProxyPass          /service1    http://localhost:8000/service1
ProxyPassReverse   /service1    http://localhost:8000/service1

<Proxy http://localhost:8000/service1>

	Require all granted

	Options None

</Proxy>
```

The most important directive is ProxyPass. It defines a `/service1` path and specifies how it is mapped to the backend: To the service defined above running on our own host, localhost, on port 8000. The path to the application server is again `/service1`. We are proxying symmetrically, because the frontend path is identical to the backend path. This mapping is however not absolutely required. Technically, it would be entirely possible to proxy `service1` to `/`, but this results to administrative difficulties and misunderstandings, if a path in the application log file no longer maps to the path on the reverse proxy and the requests can no longer be correlated easily.

On the next line comes a related directive that despite having a similar name performs only a small auxiliary function. Redirect responses from the backend are fully qualified in http-compliant form. Such as `https://backend.example.com/service1`, for example. The address is however not accessible by the client. For this reason, the reverse proxy has to rewrite the backend’s location header, `backend.example.com`, replacing it with its own name and thus mapping it back to its own namespace. ProxyPassReverse, with such a great name, only has a simple search and replace feature touching the location headers. As already seen in the ProxyPass directive, proxying is again symmetric: the paths are rewritten 1:1. We are free to ignore this rule, but I urgently recommend keeping it, because misunderstandings and confusion lie beyond. In addition to accessing location headers, there is a series of further reverse directives for handling things like cookies. They can be useful from case to case.

### Step 4: Proxy stanza

Continuing on in the configuration: now comes the Proxy block where the connection to the backend is more precisely defined. Specifically, this is where requests are authenticated and authorized. Further below in the tutorial we will also be adding a load balancer to this block.

The proxy block is similar to the location and the directory block we have previously become familiar with in our configuration. These are called containers. Containers specify to the web server how to structure the work. When a container appears in the configuration, it prepares a processing structure for it. In the case of `mod_proxy` the backend can also be accessed without a Proxy container. However, access protection is not taken into account and other directives no longer have any place where it can be inserted. Without the Proxy block the processing of complex servers remains a bit haphazard and it would do us well to configure this part as well. Using the ProxySet directive, we could intervene even more here and specify things like the connection behavior. Min, max and smax can be used to specify the number of threads assigned to the proxy connection pool. This can impact performance from case to case. The keep-alive behavior of the proxy connection can be influenced and a variety of different timeouts defined for it. Additional information is available in the Apache Project documentation.

### Step 5: Defining exceptions when proxying and making other settings

The `ProxyPass` directive we are using has forwarded all requests for `/service1` to the backend. However, in practice it is often the case that you don’t want to forward everything. Let’s suppose there’s a path `/service1/admin` that we don’t want to expose to the internet. This can also be prevented by the appropriate `ProxyPass` setting, where the exception is initiated by using an exclamation mark. What's important is to define the exception before configuring the actual proxy command:

```bash
ProxyPass          /service1/admin !
ProxyPass          /service1         http://localhost:8000/service1
ProxyPassReverse   /service1         http://localhost:8000/service1
```

You often see configurations that forward the entire namespace below `/` to the backend. Then a number of exceptions to the pattern above are often defined. I think this is the wrong approach and I prefer to forward only what is actually being processed. The advantage is obvious: scanners and automated attacks looking for their next victim from a pool of IP addresses on the internet make requests for a lot of non-existent paths on our server. We can now forward them to the backend and may overload the backend or even put it in danger. Or we can just drop these requests on the reverse proxy server. The latter is clearly preferable for security-related reasons.

An essential directive which may optionally be part of the proxy concerns the timeout. We defined our own timeout value for our server. This timeout is also used by the server for the connection to the backend. But this is not always wise, because while we can expect from the client that it will quickly make its request and not take its sweet time, depending on the backend application, it can take a while until the response is processed. For a short, general timeout which is wise to have for the client for defensive reasons, the reverse proxy would interrupt access to the backend too quickly. For this reason, there is a ProxyTimeout directive which affects only the connection to the backend. By the way, time measurement is not the total processing time on the backend, but the duration of time between IP packets: When the backend sends part of the response the clock is reset.

```bash
ProxyTimeout            60
```

Now comes time to fix the host header. Via the HTTP request host header the client specifies which of a server’s VirtualHosts to use for the request. If there are multiple VirtualHosts being operated using the same IP address, this value is important. However, when forwarding the reverse proxy normally sets a new host header, specifically the one from the backend system. This is often undesired, because in many cases the backend system sets its links based on the host header. Fully qualified links for a backend application may be a bad practice, but we avoid conflicts if we make clear from the beginning that the host header should be preserved and forwarded as is by the backend.

```bash
ProxyPreserveHost       On
```

Backend systems often pay less attention to security than a reverse proxy. Error messages are one place this is obvious. Detailed error messages are often desirable since they enable the developer or backend administrator to get at the root of the problem. But we don’t want to distribute them over the internet, because without authentication on the reverse proxy an attacker could always be lurking behind the client. It's better to hide error messages from the backend application or to replace them with an error message from the reverse proxy. The `ProxyErrorOverride` directive intervenes in the HTTP response body and replaces it if a status code greater than or equal to 400 is present. Requests with normal statuses below 400 are not affected by this directive.

```bash
ProxyErrorOverride      On
```

### Step 6: ModRewrite

In addition to the `ProxyPass` directive, the Rewrite module can be used to enable reverse proxy features. Compared to ProxyPass, it enables more flexible configuration. We have not seen ModRewrite up to this point. Since this is a very important module, we should take a good look at it.

ModRewrite defines its own rewrite engine used to manipulate, or change, HTTP requests; This rewrite engine can run in the server or VirtualHost context. Strictly speaking, we are using two separate rewrite engines. The rewrite engine in the VirtualHost context can also be configured from the Proxy container that we learned about above. If we define a rewrite engine in the server context, then it could be shortcut if there is an engine in the VirtualHost context. In this case we have to manually ensure that the rewrite rules are being inherited. We are therefore setting up a rewrite engine in the server context, configuring an example rule and initiating the inheritance.

```bash
LoadModule              rewrite_module          modules/mod_rewrite.so

...

RewriteEngine           On
RewriteOptions          InheritDownBefore

RewriteRule   		^/$	%{REQUEST_SCHEME}://%{HTTP_HOST}/index.html  [redirect,last]
```

We initialize the engine on the server level. We then instruct the engine to pass on our rules to other rewrite engines. Specifically, so that our rules are performed before the rules further down. Then comes the actual rule. We tell the server to instruct the client to send a new request to `/index.html` for a request without a path or a request for "/" respectively. This is a redirect. What’s important is for the redirect to indicate the schema of the request, http or https as well as the host name. Relatives paths won’t work. But because we are outside the VirtualHost, we don’t see the type. And we don’t want to hard code the host name, but prefer to take the host names from client requests. Both of these values are available as variables as you can see in the example above.

Then appearing within square brackets come the flags influencing the behavior of the rewrite rule. As previously mentioned, we want a redirect and tell the engine that this is the last rule to process (`last`).

Let’s have a look at a request like this and the redirect returned:

```bash
$> curl -v http://localhost/
* Hostname was NOT found in DNS cache
*  Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 80 (#0)
> GET / HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 302 Found
< Date: Thu, 10 Dec 2015 05:24:42 GMT
* Server Apache is not blacklisted
< Server: Apache
< Location: http://localhost/index.html
< Content-Length: 211
< Content-Type: text/html; charset=iso-8859-1
< 
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>302 Found</title>
</head><body>
<h1>Found</h1>
<p>The document has moved <a href="http://localhost/index.html">here</a>.</p>
</body></html>
* Connection #0 to host localhost left intact
```

The server now responds with HTTP status code `302 Found`, corresponding to the typical redirect status code. Alternatively, 301, 303, 307 or very rarely 308 also appear. The differences are subtle, but influence the behavior of the browser. What's important then is the location header. It tells the client to make a new request, specifically for the fully qualified URL with a schema specified here. This is required for the location header. Only returning the path here, assuming that the client would then correctly conclude that it’s the same server name, would be incorrect and prohibited according to the specification (even if it works with most browsers).

In the body part of the response the redirect is included as a link in HTML text. This is provided for users to click manually, if the browser does not initiate the redirect. However, this is very unlikely and is probably only included for historical reasons.

You could now ask yourself why we are opening a rewrite engine in the server context and not dealing with everything on the VirtualHost level. In the example I chose you see that this would result in redundancy, because the redirect from "/" to "index.html" should take place on port 80 and also on encrypted port 443. This is the rule of thumb: It’s best for us to define and inherit everything being used on all VirtualHosts in the server context. We also deal with individual rules for a single VirtualHost on this level. Typically, the following rule is used to redirect all requests from port 80 to port 443, where encryption is enabled:

```bash
<VirtualHost 127.0.0.1:80>
      
	RewriteEngine		On

	RewriteRule		^/(.*)$	https://%{HTTP_HOST}/$1	[redirect,last]

	...

</VirtualHost>
```

The schema we want is now clear. But to the left of it comes a new item. We don’t suppress the path as quickly as above. We instead put it in parenthesis and use `$1` to reference the content of the parenthesis again in the redirect. This means that we are forwarding the request on port 80 using the same URL on port 443.

ModRewrite has been introduced. For further examples refer to the documentation or the sections of this tutorial below where it will become familiar with yet more recipes.

### Step 7: ModRewrite [proxy]

Let's use ModRewrite to configure a reverse proxy. We do this as follows:

```bash

<VirtualHost 127.0.0.1:443>

    ...

    RewriteEngine	On

    RewriteRule		^/service1/(.*)		http://localhost:8000/service1/$1 [proxy,last]
    ProxyPassReverse	/	              	http://localhost:8000/

    <Proxy http://localhost:8000/service1>

	Require all granted

	Options None

    </Proxy>

```

The instruction follows a pattern similar to the variation using ProxyPass. Here however, the last part of the path has to be explicitly intercepted by using a bracket and again indicated by "$1" as we saw above. Instead of the suggested redirect flag a proxy is used here. ProxyPassReverse and the proxy stanza remain identical to the setup using ProxyPass.

So much for the simple configuration using a rewrite rule. There is no real advantage over ProxyPass syntax in this example. Referencing parts of paths by using `$1`, `$2`, etc. does provide a bit of flexibility. But if we are working with rewrite rules anyway, then by rewrite rule proxying we ensure that RewriteRule and ProxyPass don’t come into conflict by touching the same request and impacting one another.

However, it may now be that we want to use a single reverse proxy to combine multiple backends or to distribute the load over multiple servers. This calls for our own load balancer. We’ll be looking at it in the next section:

### Step 8: Balancer [proxy]

We first have to load the Apache load balancer module:

```bash
LoadModule        proxy_balancer_module           modules/mod_proxy_balancer.so
LoadModule        lbmethod_byrequests_module      modules/mod_lbmethod_byrequests.so
LoadModule        slotmem_shm_module              modules/mod_slotmem_shm.so
```

Besides the load balancer module itself we also need a module that can help us distribute the requests to the different backends. We’ll take the easiest route and load the lbmethod_byrequests module.
It’s the oldest module from a series of four modules and distributes requests evenly across backends by counting them sequentially. Once to the left and once to the right for two backends.

Here is a list of all four available algorithms:

* mod_lbmethod_byrequests (counts requests)
* mod_lbmethod_bytraffic (totals sizes of requests and responses)
* mod_lbmethod_bybusyness (Load balancing based on active threads in an connection established with the backend. The backend with the lowest number of threads is given the next request)
* mod_lbmethod_heartbeat (the backend can even communicate via a heartbeat on th network and use it to inform the reverse proxy whether it has any free capacity).

The different modules are well documented online so this brief description will have to suffice for now.

Finally, we still need a module to help us manage shared segments of memory. These features are required by the proxy balancer module and provided by `mod_slotmem_shm.so`.

We are now ready to configure the load balancer. We can set it up via the RewriteRule. This modification also affects the proxy stanza, where the balancer just defined must be referenced and resolved:

```bash
    RewriteRule         ^/service1/(.*)       balancer://backend/service/$1   [proxy,last]
    ProxyPassReverse    /                     balancer://backend/

    <Proxy balancer://backend>
        BalancerMember http://localhost:8000 route=backend-port-8000
        BalancerMember http://localhost:8001 route=backend-port-8001

        Require all granted

        Options None

    </Proxy>
```

We are also defining two backends, one on the previously configured port 8000 and a second on port 8001. I recommend using `socat` to quickly set up this service on a second port and then to try it out. I have defined a number of different responses so we will be able to see from the HTTP response which backend has processed the request. This then looks like this:

```bash
$> curl -v -k https://localhost/service1/index.html https://localhost/service1/index.html
* Rebuilt URL to: https://localhost:40443/
*   Trying 127.0.0.1...
* Connected to localhost (127.0.0.1) port 40443 (#0)
* found 173 certificates in /etc/ssl/certs/ca-certificates.crt
* found 697 certificates in /etc/ssl/certs
* ALPN, offering http/1.1
* SSL connection using TLS1.2 / ECDHE_RSA_AES_256_GCM_SHA384
*        server certificate verification SKIPPED
*        server certificate status verification SKIPPED
*        common name: ubuntu (does not match 'localhost')
*        server certificate expiration date OK
*        server certificate activation date OK
*        certificate public key: RSA
*        certificate version: #3
*        subject: CN=ubuntu
*        start date: Mon, 27 Feb 2017 20:46:21 GMT
*        expire date: Thu, 25 Feb 2027 20:46:21 GMT
*        issuer: CN=ubuntu
*        compression: NULL
* ALPN, server accepted to use http/1.1
> GET /service1/index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 200 
< Date: Thu, 10 Dec 2015 05:42:14 GMT
* Server Apache is not blacklisted
< Server: Apache
< Content-Type: text/plain
< Content-Length: 28
< 
Server response, port 8000
* Connection #0 to host localhost left intact
* Found bundle for host localhost: 0x24e3660
* Re-using existing connection! (#0) with host localhost
* Connected to localhost (127.0.0.1) port 443 (#0)
> GET /service1/index.html HTTP/1.1
> User-Agent: curl/7.35.0
> Host: localhost
> Accept: */*
> 
< HTTP/1.1 200 
< Date: Thu, 10 Dec 2015 05:42:14 GMT
* Server Apache is not blacklisted
< Server: Apache
< Content-Type: text/plain
< Content-Length: 28
< 
Server response, port 8001
* Connection #0 to host localhost left intact
```

In this somewhat unusual curl call two identical request are being initiated via a single curl command. What’s also interesting is the fact that with this method curl can use HTTP keep-alive. The first request lands on the first backend, and the second one on the second backend. Let’s have a look at the entries for this in the reverse proxy’s access log:

```bash
127.0.0.1 - - [2015-12-10 06:42:14.390998] "GET /service1/index.html HTTP/1.1" 200 28 "-" "curl/7.35.0"\
localhost 127.0.0.1 443 proxy-server backend-port-8000 + "-" VmkQtn8AAQEAAH@M3zAAAAAN TLSv1.2 \
ECDHE-RSA-AES256-GCM-SHA384 538 1402 -% 7856 1216 3708 381 0 0
127.0.0.1 - - [2015-12-10 06:42:14.398995] "GET /service1/index.html HTTP/1.1" 200 28 "-" "curl/7.35.0"\
localhost 127.0.0.1 443 proxy-server backend-port-8001 + "-" VmkQtn8AAQEAAH@M3zEAAAAN TLSv1.2 \
ECDHE-RSA-AES256-GCM-SHA384 121 202 -% 7035 1121 3752 354 0 0
```

Besides the keep-alive header, the request handler is also of interest. The request was thus processed by the `proxy server handler`. We also see entries for the route, specifically the values defined as `backend-port-8000` and `backend-port-8001`. This makes it possible to determine from the server's access log the exact route a request took.

In a subsequent tutorial we will be seeing that the proxy balancer can also be used in other situations. For the moment we will however be content with what is happening and will now be turning to RewriteMaps. A RewriteMap is an auxiliary structure which again increases the power of ModRewrite. Combined with the proxy server, flexibility rises substantially.

### Step 9: RewriteMap [proxy]

RewriteMaps come in a number of different variations. They works by assigning a value to a key parameter at every request. A hash table is a simple example. But it is then also possible to configure external scripts as a programmable RewriteMap. The following types of maps are possible:

* txt : A key value pair in a text file is searched for here.
* rnd : Several values can be specified for each key here. They are then selected at random.
* dbm : This variation works like the txt variation, but provides a big speed advantage as a binary hash table is used.
* int : This abbreviation stands for internal function and refers to a function from the following list: `toupper`, `tolower`, `escape` and `unescape`.
* prg : An external script is invoked in this variation. The script is started along with the server and each time the RewriteMap is accessed receives new input via STDIN.
* dbd und fastdbd : The response value is searched for in a database request.

This list makes clear that RewriteMaps are extremely flexible and can be used in a variety of situations. Determining the backend for proxying is only one of many possible applications. In our example we want to ensure that the request from a specific client always goes to the same backend. There are a number of different ways of doing this, specifically, by setting a cookie. But we don’t want to intervene in the requests. We could divide by network ranges. But how to prevent a large number of clients from a specific network range from all being taken to the same backend? Some kind of distribution has to take place. To do so, we combine ModSecurity with using ModRewrite and a RewriteMap. Let’s have a look at it step by step.

First, we calculate a hash value from the client’s IP address. This means that we are converting the IP address into a seemingly random hexadecimal string using ModSecurity:

```bash
SecRule REMOTE_ADDR	"^(.)" \
	"phase:1,id:50001,capture,nolog,t:sha1,t:hexEncode,setenv:IPHashChar=%{TX.1}"
```

We have used hexEncode to convert the binary hash value we generated using sha1 into readable characters. We then apply the regular expression to this value. "^(.)" means that we want to find a match on the first character. Of the ModSecurity flags that follow `capture` is of interest. It indicates that we want to capture the value in the parenthesis in the previous regex condition. We then put it into the IPHashChar environment variable.

If there is any uncertainty as to whether this will really work, then the content of the variable `IPHashChar` can be printed and checked using `%{IPHashChar}e` in the server’s access log. This brings us to RewriteMap and the request itself:

```bash
RewriteMap hashchar2backend "txt:/apache/conf/hashchar2backend.txt"

RewriteCond     "%{ENV:IPHashChar}"     ^(.)
RewriteRule     ^/service1/(.*) \
                     http://${hashchar2backend:%1|localhost:8000}/service1/$1 [proxy,last]

<Proxy http://localhost:8000/service1>

    Require all granted

    Options None

</Proxy>

<Proxy http://localhost:8001/service1>

    Require all granted

    Options None

</Proxy>
```

We introduce the map by using the RewriteMap command. We assign it a name, define its type and the path to the file. RewriteMap is invoked in a RewriteRule. Before we really access the map, we enable a rewrite condition. This is done using the RewriteCond directive. There we reference the IPHashChar environment variable and determine the first byte of the variable. We know that only a single byte is included in the variation, but this won’t put a stop to our plans. On the next line then the typical start of the Proxy directive. But instead of now specifying the backend, we reference RewriteMap by the name previously assigned. After the colon comes the parameter for the request. Interestingly, we use `%1` to communicate with the rewrite conditions captured in parenthesis. The RewriteRule variable is not affected by this and continues to be referenced via `$1`. After the `%1` comes the default value separated by a pipe character. Should anything go wrong when accessing the map, then communication with localhost takes place over port 8000.

All we need now is the RewriteMap. In the code sample we specified a text file. Better performance is provided by a hash file, but this is not the focus at present. Here’s the `/apache/conf/hashchar2backend.txt` map file:

```bash
##
## RewriteMap linking hex characters with one of two backends
##
1	localhost:8000
2	localhost:8000
3	localhost:8000
4	localhost:8000
5	localhost:8000
6	localhost:8000
7	localhost:8000
8	localhost:8000
9	localhost:8001
0	localhost:8001
a	localhost:8001
b	localhost:8001
c	localhost:8001
d	localhost:8001
e	localhost:8001
f	localhost:8001
```

We are differentiating between two backends and can perform the distribution any way we want. All in all, this is more indicative of a complex recipe that we put together forming a hash for each IP address and using the first character in order to determine one of two backends in the hash tables we just saw. If the client IP address remains constant (which does not always have to be the case in practice) the result of this lookup will always be the same. This means that the client will always end up on the same backend. This is called IP stickiness. However, since this entail a hash operation and not a simple IP address lookup, two clients with a similar IP address will be given a completely different hash and will not necessarily end up on the same backend. This gives us a somewhat flat distribution of the requests yet we can still be sure that specific clients will always end up on the same backend until the IP address changes.

### Step 10: Forwarding information to backend systems

The reverse proxy server shields the application server from direct client access. However, this also means that the application server is no longer able to see certain types of information about the client and its connection to the reverse proxy. To compensate for this loss, the Proxy module sets three HTTP request header lines that describe the reverse proxy:

* X-Forwarded-For : The IP address of the reverse proxy
* X-Forwarded-Host : The original HTTP host header in the client request
* X-Forwarded-Server : The name of the reverse proxy server

If multiple reverse proxies are staggered behind one another then the additional IP addresses and server names are comma separated. In addition to this information about the connection, it is also a good idea to pass along yet more information. This would of course include the unique ID, uniquely identifying the request. A well-configured backend server will create a key value similar to our reverse proxy in the log file. Being able to easily correlate the different log file entries simplifies debugging in the future.

A reverse proxy is frequently used to perform authentication. Although we haven’t set that up yet, it is still wise to add this value to an expanding basic configuration. If authentication is not defined, this value simply remains empty. And finally, we want to tell the backend system about the type of encryption the client and reverse proxy agreed upon. The entire block looks like this:

```bash
RequestHeader set "X-RP-UNIQUE-ID" 	"%{UNIQUE_ID}e"
RequestHeader set "X-RP-REMOTE-USER" 	"%{REMOTE_USER}e"
RequestHeader set "X-RP-SSL-PROTOCOL" 	"%{SSL_PROTOCOL}s"
RequestHeader set "X-RP-SSL-CIPHER" 	"%{SSL_CIPHER}s"
```

Let’s see how this affects the request between the reverse proxy and the backend:

```bash
GET /service1/index.html HTTP/1.1
Host: localhost
User-Agent: curl/7.35.0
Accept: */*
X-RP-UNIQUE-ID: VmpSwH8AAQEAAG@hXBcAAAAC
X-RP-REMOTE-USER: (null)
X-RP-SSL-PROTOCOL: TLSv1.2
X-RP-SSL-CIPHER: ECDHE-RSA-AES256-GCM-SHA384
X-Forwarded-For: 127.0.0.1
X-Forwarded-Host: localhost
X-Forwarded-Server: localhost
Connection: close
```

The different extended header lines are listed sequentially and are filled in with values where present.

### Step 11 (Goodie): Configuration of the complete reverse proxy server

This small extension brings us to the end of this tutorial and also to the end of the basic block of different tutorials. Over several tutorials we have seen how to set up an Apache web server for a lab, from compiling it to the basic configuration, and ModSecurity tuning to reverse proxies, gaining deep insight into the how of the server and its most important modules work.

Now, here’s the complete configuration for the reverse proxy server that we worked out in the last tutorials.

```bash
ServerName        localhost
ServerAdmin       root@localhost
ServerRoot        /apache
User              www-data
Group             www-data
PidFile           logs/httpd.pid

ServerTokens      Prod
UseCanonicalName  On
TraceEnable       Off

Timeout           10
MaxRequestWorkers 100

Listen            127.0.0.1:80
Listen            127.0.0.1:443

LoadModule        mpm_event_module        modules/mod_mpm_event.so
LoadModule        unixd_module            modules/mod_unixd.so

LoadModule        log_config_module       modules/mod_log_config.so
LoadModule        logio_module            modules/mod_logio.so
LoadModule        rewrite_module          modules/mod_rewrite.so

LoadModule        authn_core_module       modules/mod_authn_core.so
LoadModule        authz_core_module       modules/mod_authz_core.so

LoadModule        ssl_module              modules/mod_ssl.so
LoadModule        headers_module          modules/mod_headers.so

LoadModule        unique_id_module        modules/mod_unique_id.so
LoadModule        security2_module        modules/mod_security2.so

LoadModule        proxy_module            modules/mod_proxy.so
LoadModule        proxy_http_module       modules/mod_proxy_http.so
LoadModule        proxy_balancer_module   modules/mod_proxy_balancer.so
LoadModule        lbmethod_byrequests_module modules/mod_lbmethod_byrequests.so
LoadModule        slotmem_shm_module      modules/mod_slotmem_shm.so


ErrorLogFormat          "[%{cu}t] [%-m:%-l] %-a %-L %M"
LogFormat "%h %{GEOIP_COUNTRY_CODE}e %u [%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] \"%r\" %>s %b \
\"%{Referer}i\" \"%{User-Agent}i\" %v %A %p %R %{BALANCER_WORKER_ROUTE}e %X \"%{cookie}n\" \
%{UNIQUE_ID}e %{SSL_PROTOCOL}x %{SSL_CIPHER}x %I %O %{ratio}n%% \
%D %{ModSecTimeIn}e %{ApplicationTime}e %{ModSecTimeOut}e \
%{ModSecAnomalyScoreIn}e %{ModSecAnomalyScoreOut}e" extended

LogFormat "[%{%Y-%m-%d %H:%M:%S}t.%{usec_frac}t] %{UNIQUE_ID}e %D \
PerfModSecInbound: %{TX.perf_modsecinbound}M \
PerfAppl: %{TX.perf_application}M \
PerfModSecOutbound: %{TX.perf_modsecoutbound}M \
TS-Phase1: %{TX.ModSecTimestamp1start}M-%{TX.ModSecTimestamp1end}M \
TS-Phase2: %{TX.ModSecTimestamp2start}M-%{TX.ModSecTimestamp2end}M \
TS-Phase3: %{TX.ModSecTimestamp3start}M-%{TX.ModSecTimestamp3end}M \
TS-Phase4: %{TX.ModSecTimestamp4start}M-%{TX.ModSecTimestamp4end}M \
TS-Phase5: %{TX.ModSecTimestamp5start}M-%{TX.ModSecTimestamp5end}M \
Perf-Phase1: %{PERF_PHASE1}M \
Perf-Phase2: %{PERF_PHASE2}M \
Perf-Phase3: %{PERF_PHASE3}M \
Perf-Phase4: %{PERF_PHASE4}M \
Perf-Phase5: %{PERF_PHASE5}M \
Perf-ReadingStorage: %{PERF_SREAD}M \
Perf-WritingStorage: %{PERF_SWRITE}M \
Perf-GarbageCollection: %{PERF_GC}M \
Perf-ModSecLogging: %{PERF_LOGGING}M \
Perf-ModSecCombined: %{PERF_COMBINED}M" perflog

LogLevel                      debug
ErrorLog                      logs/error.log
CustomLog                     logs/access.log extended
CustomLog                     logs/modsec-perf.log perflog env=write_perflog


# == ModSec Base Configuration

SecRuleEngine                 On

SecRequestBodyAccess          On
SecRequestBodyLimit           10000000
SecRequestBodyNoFilesLimit    64000

SecResponseBodyAccess         On
SecResponseBodyLimit          10000000

SecPcreMatchLimit             100000
SecPcreMatchLimitRecursion    100000

SecTmpDir                     /tmp/
SecUploadDir                  /tmp/
SecDataDir                    /tmp/

SecDebugLog                   /apache/logs/modsec_debug.log
SecDebugLogLevel              0

SecAuditEngine                RelevantOnly
SecAuditLogRelevantStatus     "^(?:5|4(?!04))"
SecAuditLogParts              ABEFHIJKZ

SecAuditLogType               Concurrent
SecAuditLog                   /apache/logs/modsec_audit.log
SecAuditLogStorageDir         /apache/logs/audit/

SecDefaultAction              "phase:1,pass,log,tag:'Local Lab Service'"


# == ModSec Rule ID Namespace Definition
# Service-specific before Core-Rules:    10000 -  49999
# Service-specific after Core-Rules:     50000 -  79999
# Locally shared rules:                  80000 -  99999
#  - Performance:                        90000 -  90199
# Recommended ModSec Rules (few):       200000 - 200010
# OWASP Core-Rules:                     900000 - 999999


# === ModSec timestamps at the start of each phase (ids: 90000 - 90009)

SecAction "id:90000,phase:1,nolog,pass,setvar:TX.ModSecTimestamp1start=%{DURATION}"
SecAction "id:90001,phase:2,nolog,pass,setvar:TX.ModSecTimestamp2start=%{DURATION}"
SecAction "id:90002,phase:3,nolog,pass,setvar:TX.ModSecTimestamp3start=%{DURATION}"
SecAction "id:90003,phase:4,nolog,pass,setvar:TX.ModSecTimestamp4start=%{DURATION}"
SecAction "id:90004,phase:5,nolog,pass,setvar:TX.ModSecTimestamp5start=%{DURATION}"
                      
# SecRule REQUEST_FILENAME "@beginsWith /" \
#    "id:90005,phase:5,t:none,nolog,noauditlog,pass,setenv:write_perflog"



# === ModSec Recommended Rules (in modsec src package) (ids: 200000-200010)

SecRule REQUEST_HEADERS:Content-Type "(?:application(?:/soap\+|/)|text/)xml" \
  "id:200000,phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=XML"

SecRule REQUEST_HEADERS:Content-Type "application/json" \
  "id:200001,phase:1,t:none,t:lowercase,pass,nolog,ctl:requestBodyProcessor=JSON"

SecRule REQBODY_ERROR "!@eq 0" \
  "id:200002,phase:2,t:none,deny,status:400,log,msg:'Failed to parse request body.',\
logdata:'%{reqbody_error_msg}',severity:2"

SecRule MULTIPART_STRICT_ERROR "!@eq 0" \
"id:200003,phase:2,t:none,log,deny,status:403, \
msg:'Multipart request body failed strict validation: \
PE %{REQBODY_PROCESSOR_ERROR}, \
BQ %{MULTIPART_BOUNDARY_QUOTED}, \
BW %{MULTIPART_BOUNDARY_WHITESPACE}, \
DB %{MULTIPART_DATA_BEFORE}, \
DA %{MULTIPART_DATA_AFTER}, \
HF %{MULTIPART_HEADER_FOLDING}, \
LF %{MULTIPART_LF_LINE}, \
SM %{MULTIPART_MISSING_SEMICOLON}, \
IQ %{MULTIPART_INVALID_QUOTING}, \
IP %{MULTIPART_INVALID_PART}, \
IH %{MULTIPART_INVALID_HEADER_FOLDING}, \
FL %{MULTIPART_FILE_LIMIT_EXCEEDED}'"

SecRule TX:/^MSC_/ "!@streq 0" \
  "id:200005,phase:2,t:none,deny,status:500,\
  msg:'ModSecurity internal error flagged: %{MATCHED_VAR_NAME}'"


# === ModSec Core Rules Base Configuration (ids: 900000-900999)

Include    /apache/conf/crs/crs-setup.conf

SecAction "id:900110,phase:1,pass,nolog,\
  setvar:tx.inbound_anomaly_score_threshold=5,\
  setvar:tx.outbound_anomaly_score_threshold=4"

SecAction "id:900000,phase:1,pass,nolog,\
  setvar:tx.paranoia_level=1"


# === ModSec Core Rules: Runtime Exclusion Rules (ids: 10000-49999)

# ...


# === ModSecurity Core Rules Inclusion

Include    /apache/conf/crs/rules/*.conf


# === ModSec Core Rules: Startup Time Rules Exclusions

# ...


# === ModSec timestamps at the end of each phase (ids: 90010 - 90019)

SecAction "id:90010,phase:1,pass,nolog,setvar:TX.ModSecTimestamp1end=%{DURATION}"
SecAction "id:90011,phase:2,pass,nolog,setvar:TX.ModSecTimestamp2end=%{DURATION}"
SecAction "id:90012,phase:3,pass,nolog,setvar:TX.ModSecTimestamp3end=%{DURATION}"
SecAction "id:90013,phase:4,pass,nolog,setvar:TX.ModSecTimestamp4end=%{DURATION}"
SecAction "id:90014,phase:5,pass,nolog,setvar:TX.ModSecTimestamp5end=%{DURATION}"


# === ModSec performance calculations and variable export (ids: 90100 - 90199)

SecAction "id:90100,phase:5,pass,nolog,\
  setvar:TX.perf_modsecinbound=%{PERF_PHASE1},\
  setvar:TX.perf_modsecinbound=+%{PERF_PHASE2},\
  setvar:TX.perf_application=%{TX.ModSecTimestamp3start},\
  setvar:TX.perf_application=-%{TX.ModSecTimestamp2end},\
  setvar:TX.perf_modsecoutbound=%{PERF_PHASE3},\
  setvar:TX.perf_modsecoutbound=+%{PERF_PHASE4},\
  setenv:ModSecTimeIn=%{TX.perf_modsecinbound},\
  setenv:ApplicationTime=%{TX.perf_application},\
  setenv:ModSecTimeOut=%{TX.perf_modsecoutbound},\
  setenv:ModSecAnomalyScoreIn=%{TX.anomaly_score},\
  setenv:ModSecAnomalyScoreOut=%{TX.outbound_anomaly_score}"

# === ModSec finished


RewriteEngine           On
RewriteOptions          InheritDownBefore

RewriteRule             ^/$  %{REQUEST_SCHEME}://%{HTTP_HOST}/index.html  [redirect,last]


SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key
SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem

SSLProtocol             All -SSLv2 -SSLv3
SSLCipherSuite          'kEECDH+ECDSA kEECDH kEDH HIGH +SHA !aNULL !eNULL !LOW !MEDIUM !MD5 !EXP !DSS \
!PSK !SRP !kECDH !CAMELLIA !RC4'
SSLHonorCipherOrder     On

SSLRandomSeed           startup file:/dev/urandom 2048
SSLRandomSeed           connect builtin

DocumentRoot            /apache/htdocs

<Directory />
      
      Require all denied

      Options SymLinksIfOwnerMatch

</Directory>

<VirtualHost 127.0.0.1:80>

    RewriteEngine     On

    RewriteRule       ^/(.*)$  https://%{HTTP_HOST}/$1  [redirect,last]
    
    <Directory /apache/htdocs>

        Require all granted

        Options None

    </Directory>

</VirtualHost>

<VirtualHost 127.0.0.1:443>
    
    SSLEngine On
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"

    ProxyTimeout              60
    ProxyErrorOverride        On

    RewriteEngine             On

    RewriteRule               ^/service1/(.*)   http://localhost:8000/service1/$1 [proxy,last]
    ProxyPassReverse          /                 http://localhost:8000/


    <Proxy http://localhost:8000/service1>

        Require all granted

        Options None

    </Proxy>

    <Directory /apache/htdocs>

        Require all granted

        Options None

    </Directory>

</VirtualHost>
```

### References

* Apache mod_proxy [https://httpd.apache.org/docs/2.4/mod/mod_proxy.html](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html)
* Apache mod_rewrite [https://httpd.apache.org/docs/2.4/mod/mod_rewrite.html](https://httpd.apache.org/docs/2.4/mod/mod_rewrite.html)

### License / Copying / Further use

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
