## Handling False Positives with the OWASP ModSecurity Core Rule Set

### What are we doing?

*False positives* are annoying for users and operators alike. The users are blocked when working with an application and operators have their logs filled and they are no longer able to identify the attackers. We are thus reducing the number of *false positives* for a fresh installation of the *OWASP ModSecurity Core Rule Set* and set the anomaly limits to a stricter level step by step.

### Why are we doing this?

A fresh installation of the *Core Rule Set* (CRS) will typically have some false alarms. In some cases, namely at higher paranoia levels, there can be thousands of them. In the last tutorial, we saw a number of approaches for suppressing individual false alarms. That looked really hard. What we're missing is a strategy for coping with false alarms on a scale and this tutorial will show you one. It is obvious, reducing the number of false alarms is the prerequisite for lowering the CRS anomaly threshold and this, in turn, is required in order to use *ModSecurity* to actually ward off attackers. And only after the false alarms really are disabled, or at least curtailed to a large extent, do we get a clear picture of the real attackers.

### Requirements

* An Apache web server, ideally one created using the file structure shown in [Tutorial 1 (Compiling an Apache web server)](https://www.netnea.com/cms/apache-tutorial-1_compiling-apache/).
* Understanding of the minimal configuration from [Tutorial 2 (Configuring a minimal Apache server)](https://www.netnea.com/cms/apache-tutorial-2_minimal-apache-configuration/).
* An Apache web server with SSL/TLS support as shown in [Tutorial 4 (Configuring an SSL server)](https://www.netnea.com/cms/apache-tutorial-4_configuring-ssl-tls/).
* An Apache web server with extended access log as shown in [Tutorial 5 (Extending and analyzing the access log)](https://www.netnea.com/cms/apache-tutorial-5/apache-tutorial-5_extending-access-log/).
* An Apache web server with ModSecurity as shown in [Tutorial 6 (Embedding ModSecurity)](https://www.netnea.com/cms/apache-tutorial-6/apache-tutorial-6_embedding-modsecurity/).
* An Apache web server with the Core Rule Set, as shown in [Tutorial 7 (Including the Core Rule Set)](https://www.netnea.com/cms/apache-tutorial-7_including-modsecurity-core-rules/)

There is no point in learning to fight false positives on a lab server without traffic. What you need is a real set of false alarms. I have prepared a script that performs 10,000 requests against localhost. The requests are extracted from a browser session and transformed into curl requests so you can run them easily. When used against CRS v3.3.2, you will get the false positives, this tutorial is based on.

If you do not want to run the script yourself, then you can also download the example logs from my run:

* [10K-traffic-generator.sh](https://www.netnea.com/files/10K-traffic-generator.sh)
* [tutorial-8-example-access.log](https://www.netnea.com/files/tutorial-8-example-access.log)
* [tutorial-8-example-error.log](https://www.netnea.com/files/tutorial-8-example-error.log)

How did I arrive with this traffic generator script? After all, it is difficult to provide real production logs for an exercise due to all the sensitive data in the logs. So, I went and created false positives from scratch in my browser. With the Core Rule Set 2.2.x, this would have been simple, but with the 3.3 release (3.3.2 to be exact), most of the false positives in the default install are now gone. What I did was set the CRS to Paranoia Level 4 and then install a local Drupal site. I then published a couple of articles about SQL injections and then read the articles in the browser, combined with the casual search for individual SQL statements. All very harmless, but very alarming for CRS. And this, I repeated up to 10,000 requests.

Drupal and the core rules are not really in a loving relationship. Whenever the two software packages meet, they tend to have a falling out with each other, since the CRS is so pedantic and Drupal's habit of having square brackets in parameter names drives the CRS crazy. However, the default CRS3 installation at Paranoia Level 1, and especially the new optional exclusion rules for Drupal (see the `crs-setup.conf` file and [this blog post](https://www.netnea.com/cms/2016/11/22/securing-drupal-with-modsecurity-and-the-core-rule-set-crs3/) for details), wards off almost all of the remaining false positives with a core Drupal installation.

But things look completely different when you do not use these exclusion rules and if you raise the Paranoia Level to 4, you will get plenty of false positives. For the 10,000 requests in my test run, I received over 28,000 false alarms and I expect the same number for your setup. That should do for a training session.

### Step 1: Defining a Policy to Fight False Positives

The problem with false positives is that if you are unlucky, they flood you like an avalanche and you do not know where to start the clean up. What you need is a plan and there is no official documentation proposing one. So here we go: This is my recommended approach to fighting false alarms:

* Always work in blocking mode
* Highest scoring requests go first
* Work in several iterations

What does that mean? The default installation comes in blocking mode and with an anomaly threshold of 5 for the requests. In fact, this is a very good goal for our work, but it's an overambitious start on an existing production server. The risk is that a false positive raises an alarm, the wrong customer's browser is blocked, a phone call to a manager ensues and you are forced to switch off the Web Application Firewall. In many installations I have seen, this was the end of the story.

Don't let a badly tuned system catch you like this. Instead, start with a high threshold for the anomaly score. Let's say 10,000 for the requests and also 10,000 for the responses for symmetry's sake (in practice, the responses do not score very high). That way no customer is ever going to be blocked, while you get reports of false alarms and enough time to weed them out.

If you have a proper security program, this is all performed during an extensive testing phase, so the service never hits production without a strict configuration. But if you start with ModSecurity on an existing production service, starting out with a high threshold in production is the preferred method with minimal interruption to existing customers (zero impact, if you work diligently). 

The problem with integrating ModSecurity in production is the fact that false positives and real alarms are intermixed. In order to tune your installation, you need to separate the two groups to really work on the false positives alone. This is not always easy. Manual review helps, restricting to known IP addresses, pre-authentication, testing/tuning on a test system separated from the internet, filtering the access log by country of origin for the IP address, etc... It's a large topic and making general recommendations is difficult. But please do take this seriously. Years ago, I demonstrated the exclusion of a false positive in a workshop - and the example alarm I used turned out to be a real attack. Needless to say, I learned my lesson.

There is another question that we need to get out of the way: Doesn't disabling rules actually lower the security of the site? Yes it does, but we need to keep things in perspective. In an ideal setup, all rules would be intact, the paranoia level would be very high (thus a total of 200 rules in place) and the anomaly limit very low; but the application would run without any problems or false alarms. But in practice, this won't work outside of the rarest of cases. If we raise the anomaly threshold, then the alerts are still there, but the attackers are no longer affected. If we reduce the paranoia level, we disable dozens of rules with one setting. If we talk to the developers about changing their software so that the false positives go away, we spend a lot of time arguing without much chance of success (at least in my experience). So disabling a single rule from a set of 200 rules is the best of all the bad solutions. The worst of all the bad solutions would be to disable ModSecurity altogether. And as this is very real in many organizations, I would rather disable individual rules based on a false positive than run the risk of being forced to kill the WAF.


### Step 2: Getting an Overview

The character of the application, the paranoia level and the amount of traffic all influence the amount of false positives you get in your logs. In the first run, a couple of thousand or one hundred thousand requests will do. Once you have that in your access log, it's time to take a look. Let's get an overview of the situation: Let's look at the example logs!

One would think that the error log with the alerts is the place were you would start. But, we are looking at the access log first. We defined the log format in a way that gives us the anomaly scores for every request. This helps us with this step.

In the previous tutorial, we used the script [modsec-positive-stats.rb](https://www.netnea.com/files/modsec-positive-stats.rb). We return to this script with the example access log as the target:

```bash
$> cat tutorial-8-example-access.log | alscores | modsec-positive-stats.rb
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   5014 |  50.1399% |  50.1399% |  49.8601%
Reqs with incoming score of   1 |      0 |   0.0000% |  50.1399% |  49.8601%
Reqs with incoming score of   2 |      0 |   0.0000% |  50.1399% |  49.8601%
Reqs with incoming score of   3 |      0 |   0.0000% |  50.1399% |  49.8601%
Reqs with incoming score of   4 |      0 |   0.0000% |  50.1399% |  49.8601%
Reqs with incoming score of   5 |   3562 |  35.6200% |  85.7599% |  14.2401%
Reqs with incoming score of   6 |      0 |   0.0000% |  85.7599% |  14.2401%
Reqs with incoming score of   7 |      0 |   0.0000% |  85.7599% |  14.2401%
Reqs with incoming score of   8 |      1 |   0.0100% |  85.7700% |  14.2300%
Reqs with incoming score of   9 |      0 |   0.0000% |  85.7700% |  14.2300%
Reqs with incoming score of  10 |      2 |   0.0200% |  85.7899% |  14.2101%
Reqs with incoming score of  11 |      0 |   0.0000% |  85.7899% |  14.2101%
Reqs with incoming score of  12 |      0 |   0.0000% |  85.7899% |  14.2101%
Reqs with incoming score of  13 |      0 |   0.0000% |  85.7899% |  14.2101%
Reqs with incoming score of  14 |      0 |   0.0000% |  85.7899% |  14.2101%
Reqs with incoming score of  15 |      0 |   0.0000% |  85.7899% |  14.2101%
Reqs with incoming score of  16 |      0 |   0.0000% |  85.7899% |  14.2101%
Reqs with incoming score of  17 |      0 |   0.0000% |  85.7899% |  14.2101%
Reqs with incoming score of  18 |      0 |   0.0000% |  85.7899% |  14.2101%
Reqs with incoming score of  19 |      0 |   0.0000% |  85.7899% |  14.2101%
Reqs with incoming score of  20 |     41 |   0.4100% |  86.1999% |  13.8001%
Reqs with incoming score of  21 |      0 |   0.0000% |  86.1999% |  13.8001%
Reqs with incoming score of  22 |      0 |   0.0000% |  86.1999% |  13.8001%
Reqs with incoming score of  23 |      0 |   0.0000% |  86.1999% |  13.8001%
Reqs with incoming score of  24 |     50 |   0.5000% |  86.6999% |  13.3001%
Reqs with incoming score of  25 |      0 |   0.0000% |  86.6999% |  13.3001%
Reqs with incoming score of  26 |      0 |   0.0000% |  86.6999% |  13.3001%
Reqs with incoming score of  27 |      0 |   0.0000% |  86.6999% |  13.3001%
Reqs with incoming score of  28 |      0 |   0.0000% |  86.6999% |  13.3001%
Reqs with incoming score of  29 |      0 |   0.0000% |  86.6999% |  13.3001%
Reqs with incoming score of  30 |     76 |   0.7600% |  87.4599% |  12.5401%
Reqs with incoming score of  31 |      0 |   0.0000% |  87.4599% |  12.5401%
Reqs with incoming score of  32 |      0 |   0.0000% |  87.4599% |  12.5401%
Reqs with incoming score of  33 |      0 |   0.0000% |  87.4599% |  12.5401%
Reqs with incoming score of  34 |      0 |   0.0000% |  87.4599% |  12.5401%
Reqs with incoming score of  35 |     76 |   0.7600% |  88.2200% |  11.7800%
Reqs with incoming score of  36 |      0 |   0.0000% |  88.2200% |  11.7800%
Reqs with incoming score of  37 |      5 |   0.0500% |  88.2700% |  11.7300%
Reqs with incoming score of  38 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  39 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  40 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  41 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  42 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  43 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  44 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  45 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  46 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  47 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  48 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  49 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  50 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  51 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  52 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  53 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  54 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  55 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  56 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  57 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  58 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  59 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  60 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  61 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  62 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  63 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  64 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  65 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  66 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  67 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  68 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  69 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  70 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  71 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  72 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  73 |      0 |   0.0000% |  88.2700% |  11.7300%
Reqs with incoming score of  74 |    388 |   3.8800% |  92.1499% |   7.8501%
Reqs with incoming score of  75 |      0 |   0.0000% |  92.1499% |   7.8501%
Reqs with incoming score of  76 |      0 |   0.0000% |  92.1499% |   7.8501%
Reqs with incoming score of  77 |      0 |   0.0000% |  92.1499% |   7.8501%
Reqs with incoming score of  78 |     76 |   0.7600% |  92.9100% |   7.0900%
Reqs with incoming score of  79 |      1 |   0.0100% |  92.9200% |   7.0800%
Reqs with incoming score of  80 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  81 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  82 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  83 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  84 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  85 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  86 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  87 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  88 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  89 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  90 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  91 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  92 |      0 |   0.0000% |  92.9200% |   7.0800%
Reqs with incoming score of  93 |    701 |   7.0100% |  99.9300% |   0.0700%
Reqs with incoming score of  94 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of  95 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of  96 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of  97 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of  98 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of  99 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 100 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 101 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 102 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 103 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 104 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 105 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 106 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 107 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 108 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 109 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 110 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 111 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 112 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 113 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 114 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 115 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 116 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 117 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 118 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 119 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 120 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 121 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 122 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 123 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 124 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 125 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 126 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 127 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 128 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 129 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 130 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 131 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 132 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 133 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 134 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 135 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 136 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 137 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 138 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 139 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 140 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 141 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 142 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 143 |      0 |   0.0000% |  99.9300% |   0.0700%
Reqs with incoming score of 144 |      1 |   0.0100% |  99.9400% |   0.0600%
Reqs with incoming score of 145 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 146 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 147 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 148 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 149 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 150 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 151 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 152 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 153 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 154 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 155 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 156 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 157 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 158 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 159 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 160 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 161 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 162 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 163 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 164 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 165 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 166 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 167 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 168 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 169 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 170 |      0 |   0.0000% |  99.9400% |   0.0600%
Reqs with incoming score of 171 |      6 |   0.0600% | 100.0000% |   0.0000%

Incoming average:  12.6065    Median   0.0000    Standard deviation  27.5065


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. outgoing score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with outgoing score of   0 |  10000 | 100.0000% | 100.0000% |   0.0000%

Outgoing average:   0.0000    Median   0.0000    Standard deviation   0.0000
```

So we have 10,000 requests and about half of them pass without raising any alarm. Over 3,500 requests come in with an anomaly score of 5 and of the remaining requests form two distinct anomaly score clusters around 74 and 93. Then there is a very long tail with the highest group of requests scoring 171. That's more than 30 critical alerts on a single request (a critical alert gives 5 points, 30 critical alerts will thus score 200). Wow.

Let's visualize this:

<img src="/files/tutorial-8-distribution-untuned.png" alt="Untuned Distribution" width="950" height="550" />

_A quick overview over the stats generated above_



This is only a graph cobbled together on the fly. But it shows the problem that most requests are located near the left. They did not score at all, or they scored exactly 5 points. But there requests with higher scores and there is even a handful of outliers very far on the right outside the frame. So where do we start? 

We start with the request returning the highest anomaly score, we start on the right side of the graph! This makes sense because we are in blocking mode and we would like to reduce the threshold. The group of requests standing in our way are the six requests with a score of 171 and the single request with a score of 144. Let's write rule exclusions to suppress the alarms leading to these scores.



### Step 3: The first batch of rule exclusions

In order to find out what rules stand behind the anomaly scores 231 and 189, we need to link the access log to the error log. The unique request ID is this link:

```bash
$> egrep " (144|171) [0-9-]+$" tutorial-8-example-access.log | alreqid | tee ids
YOLwPjVthd6oCpPp2VVvSwAAAAI
YOLwcTVthd6oCpPp2VVw1wAAABE
YOLwcTVthd6oCpPp2VVw1gAAABU
YOLwcTVthd6oCpPp2VVw1gAAABc
YOLwcTVthd6oCpPp2VVw1wAAABY
YOLwcTVthd6oCpPp2VVw1wAAAAc
YOLwcTVthd6oCpPp2VVw1wAAAAg
```

With this one-liner, we *grep* for the requests with incoming anomaly score 144 or 171. We know it is the second item from the end of the log line. The final value is the outgoing anomaly score. In our case, all responses scored 0, but theoretically, this value could be any number or undefined (-> `-`) so it is generally a good practice to write the pattern this way. The alias *alreqid* extracts the unique ID and *tee* will show us the IDs and write them to the file *ids* at the same time.

We can then take the IDs in this file and use them to extract the alerts belonging to the requests we're focused on. We use `grep -f` to perform this step. The `-F` flag tells *grep* that our pattern file is actually a list of fixed strings separated by newlines. Thus equipped, *grep* is a lot more efficient than without the `-F` flag, which matters for very large files.  The *melidmsg* alias extracts the ID and the message explaining the alert. Combining both is very helpful. The already familiar *sucs* alias is then used to sum it all up:

```bash
$> grep -F -f ids tutorial-8-example-error.log  | melidmsg | sucs
      6 942450 SQL Hex Encoding Identified
      7 921180 HTTP Parameter Pollution (ARGS_NAMES:ids[])
     35 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
    110 920273 Invalid character in request (outside of very strict set)
    150 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
```

So these are the culprits. These are the rules driving the said seven request to the heights we encountered. Let's go through them one by one.

942450 looks for strings of the pattern `0x` with two additional hexadecimal digits. This is a hexadecimal encoding which can point to an exploit being used. The problem with this encoding is that session cookies can sometimes contain this pattern. Session cookies are randomly generated strings and at times you get this pattern in such an identifier. When you do, there is a paranoia level 2 rule that looks for attack patterns in hexadecimal encoding that try to sneak past our ruleset. This is a false positive in a very classical way.

921180 is a rule that identifies when a parameter (*ids[]* here) is submitted more than once within the same request. It's an advanced rule which appeared in the CRS3 for the first time (based on a mechanic I developed). Drupal seems to do this and we can hardly instruct it to stop this behaviour. 

942431 and 942432 are closely related. We call these siblings. They form a group with 942430, the base rule looking for 12 special characters like square brackets, colons, semicolons, asterisks, etc. (paranoia level 2). 942431 is a strict sibling doing the same things, but with a limit of 6 characters at paranoia level 3 and finally the paranoid zealot in the family, 942432, is going crazy after the 2nd special character (paranoia level 4).

Rule 920273 is pretty much self explanatory. It's a very strict rule at paranoia level 4 and it fights special characters fiercly.

So this is what we are facing for our first tuning round.

Let's look at the rule exclusion cheat sheet from the previous tutorial again. It illustrates the four basic ways to handle a false positive. This is going to be our guide as we work through them.

<a href="https://www.netnea.com/cms/rule-exclusion-cheatsheet-download/"><img src="https://www.netnea.com/files/tutorial-7-rule-exclusion-cheatsheet_small.png" alt="Rule Exclusion CheatSheet" width="476" height="673" /></a>

_Click to get to the download of the large version_

Let's start with a simple case: 920273 Invalid character in request. We could look at this in great detail and check out all the different parameters triggering this rule. Depending on the security level we want to provide for our application, this would be the right approach. But this is only an exercise and the numbers for this rule are staggering, so we will keep it simple: Let's kick this rule out completely. We'll opt for a startup rule (to be placed after the CRS include) that remove the rule 920273 from the memory of the WAF.

```bash
# === ModSec Core Rule Set: Config Time Exclusion Rules (no ids)

# ModSec Rule Exclusion: 920273 : Invalid character in request (outside of very strict set)
SecRuleRemoveById 920273
```

I suggest you always add at least a minimal comment where you describe what you are doing and also name the rule, since most people won't know the rule IDs by heart.

Next are the alerts for 942432 Restricted SQL Character Anomaly Detection. Let's take a closer look.

```bash
$> grep -F -f ids tutorial-8-example-error.log  | grep 942432 | melmatch | sucs
     75 ARGS:ids[]
     75 ARGS_NAMES:ids[]
``` 

Drupal obviously uses square brackets within the parameter name. This is not limited to IDs, but a general pattern. Two square brackets are enough to trigger the rule, so this sets off a lot of false alarms. Running after all occurrences would be very tedious, so we will kick this rule out as well (remember, it's a paranoia level 4 rule and a more relaxed version of this rule exists at PL3). 

```bash
# ModSec Rule Exclusion: 942432 : Restricted SQL Character Anomaly Detection (args): 
# number of special characters exceeded (2)
SecRuleRemoveById 942432
```

The next one is 942450. This is the rule looking for traces of hex encoding. This is a peculiar case as we can easily see:


```bash
$> grep -F -f ids tutorial-8-example-error.log  | grep 942450 | melmatch | sucs
      6 REQUEST_COOKIES:98febd3dhf84de73ab2e32889dc5f0x032a9
      6 REQUEST_COOKIES_NAMES:SESS29af1facda0a866a687d5055f0x034ca
```

As expected, it's a session cookie, but unexpectedly, the session cookie has a dynamic name on top! This means we can not simply ignore the session cookie by name, we would need to ignore cookies whose name matches a certain pattern and this is something ModSecurity does not allow us to do. The only viable approach from my perspective is to have this rule ignore all cookies. This way, the rule is still intact for post and query string parameters, but it does not trigger on cookies anymore. That's not ideal, but the best we can do in this situation. So unlike the previous rule exclusions, we limit our exclusion at two parameter (groups) and leave the rest of the rule intact. On the cheat sheet, this is the bottom left option; another startup rule exclusion but one that leaves the rule itself intact.

```bash
# ModSec Rule Exclusion: 942450 : SQL Hex Encoding Identified (severity: 5 CRITICAL)
SecRuleUpdateTargetById 942450 "!REQUEST_COOKIES"
SecRuleUpdateTargetById 942450 "!REQUEST_COOKIES_NAMES"
```

Two more to go: 921180 HTTP Parameter Pollution and 942431 Restricted SQL Character Anomaly Detection. Let's try and work in a very diligent way here. We no longer throw out the entire rule and we do not want to exclude parameters from the application of the rule entirely. Instead, we limit the rule exclusion to a certain URI pattern. That means, we will construct a rule exclusion that depends on the request in question; a runtime rule exclusion. On the cheat sheet, this is the right column.

As you can also see on the cheat sheet, these are very hard to do by hand. That's why I have developed a script that comes to your help. Please download [modsec-rulereport.rb](https://www.netnea.com/files/modsec-rulereport.rb) and put it into your `bin` folder. Try out the `--help` option of the script to get an idea of what it can do for you.

Here is how I use it to generate a rule exclusion for 942431: First I take a look at the alert again:

```bash
$> grep -F -f ids tutorial-8-example-error.log   | grep 942431 | melmatch 
ARGS:ids[]
ARGS:ids[]
ARGS:ids[]
...
ARGS:ids[]
```

So the parameter `ids[]` is affected. And it's always the same URI:

```bash
$> grep -F -f ids tutorial-8-example-error.log   | grep 942431 | meluri 
/drupal/index.php/contextual/render
/drupal/index.php/contextual/render
/drupal/index.php/contextual/render
...
/drupal/index.php/contextual/render
```

So it's a perfect use case for a runtime rule exclusion that ignores parameter `ids[]` on `/drupal/index.php/contextual/render`. Here is how to use the script:


```bash
$> grep -F -f ids tutorial-8-example-error.log | grep 942431 | \
modsec-rulereport.rb --runtime --target --byid
# ModSec Rule Exclusion: 942431 : Restricted SQL Character Anomaly Detection (args): …
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render"
	"phase:1,nolog,pass,id:10000,ctl:ruleRemoveTargetById=942431;ARGS:ids[]"
```

This output is config code. You can copy it over to your Apache / ModSecurity configuration as is, ideally together with the comment. Important: This has to be placed above the CRS include in the configuration file. If you place it afterwards, there is a chance the rule has already been executed the moment you issue the rule exclusion. So as a rule of thumb, runtime rule exclusions are always defined before the include, startup rule exclusions are defined after the include.

If we accept this rule exclusion proposal as our new config, then there is only 921180 HTTP Parameter Pollution left. The script gives us the following:

```bash
$> grep -F -f ids tutorial-8-example-error.log | grep 921180 | \
modsec-rulereport.rb --runtime --target --byid
# ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution (ARGS_NAMES:ids[])
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render"
	"phase:1,nolog,pass,id:10000,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:ids[]"
```

We can copy this over to the config again, but there is a twist. If we take it as is, there is going to be a rule collision as the script issued the new rule with ID 10000 again. Let's change that to 10001 and enter it as follows:

```bash
# ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution (ARGS_NAMES:ids[])
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render"
	"phase:1,nolog,pass,id:10001,ctl:ruleRemoveTargetById=921180;TX:paramcounter_ARGS_NAMES:ids[]"
```

If you do not want to tweak with the rule ID by hand, then you can also pass the desired base rule ID as a command line parameter `--baseruleid` or - even better still - make sure the script saves the rule ID and starts the next run with the rule ID it finds from the previous run. Look up the help page of the script to learn how this works.


### Step 4: Reducing the anomaly score threshold

We have tuned away the alerts leading to the highest anomaly scores. Actually, anything above 100 is now gone. In a production setup, I would deploy the updated configuration and observe the behaviour a bit. If the high scores are really gone, then it is time to reduce the anomaly limit. A typical first step is from 10,000 to 100. Then we do more rules exclusions, reduce to 50 or so, then to 20, 10 and 5. In fact, a limit of 5 is really strong (first critical alert blocks a request), but for sites with less security needs, a limit of 10 might just be good enough. Anything above does not really block attackers.

But before we get there, we need to add few more rule exclusions.



### Step 5: The second batch of rule exclusions

After the first batch of rule exclusions, we would observe the service. In our exercise, we can speed up the process and run the `10K-traffic-generator.sh` script again (Don't forget to restart your webserver after having added the rule exclusions in step 3 above).

Here for your discretion the log files I got with the rule exclusions defined together:

* [tutorial-8-example-access-round-2.log](https://www.netnea.com/files/tutorial-8-example-access-round-2.log)
* [tutorial-8-example-error-round-2.log](https://www.netnea.com/files/tutorial-8-example-error-round-2.log)

We start again with a look at the score distribution:

```bash
$> cat tutorial-8-example-access-round-2.log | alscores | modsec-positive-stats.rb

INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   8612 |  86.1199% |  86.1199% |  13.8801%
Reqs with incoming score of   1 |      0 |   0.0000% |  86.1199% |  13.8801%
Reqs with incoming score of   2 |      0 |   0.0000% |  86.1199% |  13.8801%
Reqs with incoming score of   3 |      0 |   0.0000% |  86.1199% |  13.8801%
Reqs with incoming score of   4 |      0 |   0.0000% |  86.1199% |  13.8801%
Reqs with incoming score of   5 |    736 |   7.3600% |  93.4799% |   6.5201%
Reqs with incoming score of   6 |      0 |   0.0000% |  93.4799% |   6.5201%
Reqs with incoming score of   7 |      0 |   0.0000% |  93.4799% |   6.5201%
Reqs with incoming score of   8 |    388 |   3.8800% |  97.3599% |   2.6401%
Reqs with incoming score of   9 |      0 |   0.0000% |  97.3599% |   2.6401%
Reqs with incoming score of  10 |     36 |   0.3600% |  97.7199% |   2.2801%
Reqs with incoming score of  11 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  12 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  13 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  14 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  15 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  16 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  17 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  18 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  19 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  20 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  21 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  22 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  23 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  24 |      0 |   0.0000% |  97.7199% |   2.2801%
Reqs with incoming score of  25 |     76 |   0.7600% |  98.4799% |   1.5201%
Reqs with incoming score of  26 |      0 |   0.0000% |  98.4799% |   1.5201%
Reqs with incoming score of  27 |      0 |   0.0000% |  98.4799% |   1.5201%
Reqs with incoming score of  28 |      0 |   0.0000% |  98.4799% |   1.5201%
Reqs with incoming score of  29 |      0 |   0.0000% |  98.4799% |   1.5201%
Reqs with incoming score of  30 |     76 |   0.7600% |  99.2400% |   0.7600%
Reqs with incoming score of  31 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  32 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  33 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  34 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  35 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  36 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  37 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  38 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  39 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  40 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  41 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  42 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  43 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  44 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  45 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  46 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  47 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  48 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  49 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  50 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  51 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  52 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  53 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  54 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  55 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  56 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  57 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  58 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  59 |      0 |   0.0000% |  99.2400% |   0.7600%
Reqs with incoming score of  60 |     76 |   0.7600% | 100.0000% |   0.0000%

Incoming average:   1.5884    Median   0.0000    Standard deviation   6.4117


OUTGOING                     Num of req. | % of req. |  Sum of % | Missing %
Number of outgoing req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. outgoing score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with outgoing score of   0 |  10000 | 100.0000% | 100.0000% |   0.0000%

Outgoing average:   0.0000    Median   0.0000    Standard deviation   0.0000
```

If we compare this to the first run of the statistic script, we reduced the average score from 12.6 to 1.6. This is very impressive. So by focusing on a handful of high scoring requests, we improved the whole service by a lot.

We could expect the high scoring requests of 144 and 171 to be gone, but funnily enough, the cluster at 74 and the one at 93 have also disappeared. We only covered 7 requests in the initial tuning, but two clusters with alerts from over 350 are completly gone, too. And this is not an exceptional effect. It is the standard behaviour if we work with this tuning method: a few rule exclusions that we derieved from the highest scoring requests does away with most of the false alarms.

Our next goal is the group of requests with a score of 60 so we can then lower the anomaly score threshold to 50 in the 2nd reduction round. Let's extract the rule IDs and then examine the alerts a bit.

```bash
$> egrep " 60 [0-9-]+$" tutorial-8-example-access-round-2.log | alreqid > ids
$> grep -F -f ids tutorial-8-example-error-round-2.log | melidmsg | sucs
     75 921180 HTTP Parameter Pollution (ARGS_NAMES:keys)
     75 942100 SQL Injection Attack Detected via libinjection
    150 942190 Detects MSSQL code execution and information gathering attempts
    150 942200 Detects MySQL comment-/space-obfuscated injections and backtick termination
    150 942260 Detects basic SQL authentication bypass attempts 2/3
    150 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others
    150 942480 SQL Injection Attack

```

Interestingly, the alerts all happen on the same path:

```bash
$> grep -F -f ids tutorial-8-example-error-round-2.log | meluri | sucs
    912 /drupal/index.php/search/node
```

This path points to a search form and payloads resembling SQL injections. But there is one exception: We have seen rule 921180 HTTP Parameter Pollution before. In the previous tuning round we did a diligent runtime rule exclusion to avoid this rule for parameter ids[]. Not it looks like the submission of a certain parameter name multiple time in the same request something Drupal does a lot. So the diligent approach is tedious and we better give up on that idea and kiss this rule goodbye in our Drupal context:

```bash
# ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution
SecRuleRemoveById 921180
```

All the other alerts stem from SQL injection rules. But we know this was legitimate traffic: I filled in the forms personally when I searched for SQL statements in the Drupal articles I had posted as an exercise and we are now facing a dilemma: If we suppress the rules, we open a door for SQL injections. If we leave the rules intact and reduce the limit, we will block legitimate traffic. I think it is OK to say that nobody should be using the search form to look for sql statements in our articles. But I could also say that Drupal is smart enough to fight off SQL attacks via the search form. As this is an exercise, this is our position for the moment: Let's trust Drupal and exclude these rules in this context.

How could we do this really quick? We could do a rule exclusion based on a tag, since all SQL injection rule share a tag. Here is how we can identify it (make sure you skip 921180 as that's not an SQLi rule):

```bash
$> grep -F -f ids tutorial-8-example-error-round-2.log | grep -v 921180 |  meltags | sucs
    380 paranoia-level/1
    456 paranoia-level/2
    836 application-multi
    836 attack-sqli
    836 capec/1000/152/248/66
    836 language-multi
    836 OWASP_CRS
    836 PCI/6.5.2
    836 platform-multi
```

The tag we are interested in is `attack-sqli`. Let's call the helper script with `attack-sqli` as tag parameter:

```bash
$> grep -F -f ids tutorial-8-example-error-round-2.log | grep -v 921180 | \
modsec-rulereport.rb --runtime --target --bytag attack-sqli
# ModSec Rule Exclusion: 942100 via tag attack-sqli: (Msg: SQL Injection Attack Detected via libinjection)
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node"
	"phase:1,nolog,pass,id:10000,ctl:ruleRemoveTargetByTag=attack-sqli;ARGS:keys"

# ModSec Rule Exclusion: 942190 via tag attack-sqli: (Msg: Detects MSSQL code execution and information …
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" 
	"phase:1,nolog,pass,id:10001,ctl:ruleRemoveTargetByTag=attack-sqli;ARGS:keys"

# ModSec Rule Exclusion: 942200 via tag attack-sqli: (Msg: Detects MySQL comment-/space-obfuscated …
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" 
	"phase:1,nolog,pass,id:10002,ctl:ruleRemoveTargetByTag=attack-sqli;ARGS:keys"

# ModSec Rule Exclusion: 942260 via tag attack-sqli: (Msg: Detects basic SQL authentication bypass …
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" 
	"phase:1,nolog,pass,id:10003,ctl:ruleRemoveTargetByTag=attack-sqli;ARGS:keys"

# ModSec Rule Exclusion: 942270 via tag attack-sqli: (Msg: Looking for basic sql injection. Common …
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" 
	"phase:1,nolog,pass,id:10004,ctl:ruleRemoveTargetByTag=attack-sqli;ARGS:keys"

# ModSec Rule Exclusion: 942480 via tag attack-sqli: (Msg: SQL Injection Attack)
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" 
	"phase:1,nolog,pass,id:10005,ctl:ruleRemoveTargetByTag=attack-sqli;ARGS:keys"
```

If you look closely, you will notice, that it's always the same `ctl` statement. So by attempting a rule exclusion by tag name, we get the same rule exclusion for all the individual alerts. The script could be a bit smarter and condense this by itself, but for the time being, we need to do this oursselves:

```bash
# ModSec Rule Exclusion: All SQLi rules for parameter keys on search form via tag attack-sqli
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" \
	"phase:1,nolog,pass,id:10001,ctl:ruleRemoveTargetByTag=attack-sqli;ARGS:keys"
```

Since we have removed the runtime rule exclusion for 921180 HTTP Parameter Pollution, the rule ID 921180 is free again. We re-use it for this SQLi rule exclusion.

That's it already for the 2nd tuning round: We cleaned out all the scores above 50. Time to reduce the anomaly threshold to 50, let it rest a bit and then examine the logs for the third batch.


### Step 6: The third batch of rule exclusions

I've executed the traffic generator after applying the 2nd batch of rule exclusions. If you want to skip that step, here are the log files I ended up with:

* [tutorial-8-example-access-round-3.log](https://www.netnea.com/files/tutorial-8-example-access-round-3.log)
* [tutorial-8-example-error-round-3.log](https://www.netnea.com/files/tutorial-8-example-error-round-3.log)


This brings us to the following statistics (this time only printing numbers for the incoming requests):

```bash
$> cat tutorial-8-example-access-round-3.log | alscores | modsec-positive-stats.rb --incoming
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   9535 |  95.3500% |  95.3500% |   4.6500%
Reqs with incoming score of   1 |      0 |   0.0000% |  95.3500% |   4.6500%
Reqs with incoming score of   2 |      0 |   0.0000% |  95.3500% |   4.6500%
Reqs with incoming score of   3 |    388 |   3.8800% |  99.2299% |   0.7701%
Reqs with incoming score of   4 |      0 |   0.0000% |  99.2299% |   0.7701%
Reqs with incoming score of   5 |     41 |   0.4100% |  99.6399% |   0.3601%
Reqs with incoming score of   6 |      0 |   0.0000% |  99.6399% |   0.3601%
Reqs with incoming score of   7 |      0 |   0.0000% |  99.6399% |   0.3601%
Reqs with incoming score of   8 |      0 |   0.0000% |  99.6399% |   0.3601%
Reqs with incoming score of   9 |      0 |   0.0000% |  99.6399% |   0.3601%
Reqs with incoming score of  10 |     36 |   0.3600% |  99.9999% |   0.0001%

Incoming average:   0.1729    Median   0.0000    Standard deviation   0.8842
```

So again, a great deal of the false positives disappeared because of a bunch of exclusions for a score of 60. The original plan was to go from limit 50 to limit 20 first. But the stats are much better now. We can go to 10 immediately, if we handle the 36 request standing in our way. 

```bash
$> egrep " 10 [0-9-]+$" tutorial-8-example-access-round-3.log | alreqid > ids
$> grep -F -f ids tutorial-8-example-error-round-3.log | melidmsg | sucs
     72 932160 Remote Command Execution: Unix Shell Code Found
```

Wow, that's really simple. A single rule triggering twice for every request. But what does "Remote Command Execution" mean in this context?

```bash
$> grep -F -f ids tutorial-8-example-error-round-3.log | melmatch | sucs
ARGS:account[pass][pass1]
ARGS:account[pass][pass2]
$> grep -F -f ids tutorial-8-example-error-round-3.log | grep 932160 | meldata | sucs
     72 Matched Data: /bin/bash found within ARGS:account[pass
```

This looks like there is a password `/bin/bash` here. That is probably not the smartest choice, but nothing that should really harm us, since passwords are rarely executed. In fact they are hashed before they are used in the user directory. So we can easily suppress this rule for the password parameter. Or looking forward a bit, we can expect other funny passwords to trigger all sorts of rules on the password field. In fact, this is another situation where it makes sense to disable a whole class of rules. We have multiple options. We can disable by tag as we've done before, or we can disable by rule ID range. Let's look over the various rules files for a moment:

```bash
REQUEST-901-INITIALIZATION.conf
REQUEST-903.9001-DRUPAL-EXCLUSION-RULES.conf
REQUEST-903.9002-WORDPRESS-EXCLUSION-RULES.conf
REQUEST-903.9003-NEXTCLOUD-EXCLUSION-RULES.conf
REQUEST-903.9004-DOKUWIKI-EXCLUSION-RULES.conf
REQUEST-903.9005-CPANEL-EXCLUSION-RULES.conf
REQUEST-903.9006-XENFORO-EXCLUSION-RULES.conf
REQUEST-903.9007-PHPBB-EXCLUSION-RULES.conf
REQUEST-905-COMMON-EXCEPTIONS.conf
REQUEST-910-IP-REPUTATION.conf
REQUEST-911-METHOD-ENFORCEMENT.conf
REQUEST-912-DOS-PROTECTION.conf
REQUEST-913-SCANNER-DETECTION.conf
REQUEST-920-PROTOCOL-ENFORCEMENT.conf
REQUEST-921-PROTOCOL-ATTACK.conf
REQUEST-930-APPLICATION-ATTACK-LFI.conf
REQUEST-931-APPLICATION-ATTACK-RFI.conf
REQUEST-932-APPLICATION-ATTACK-RCE.conf
REQUEST-933-APPLICATION-ATTACK-PHP.conf
REQUEST-941-APPLICATION-ATTACK-XSS.conf
REQUEST-942-APPLICATION-ATTACK-SQLI.conf
REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf
REQUEST-944-APPLICATION-ATTACK-JAVA.conf
REQUEST-949-BLOCKING-EVALUATION.conf
RESPONSE-950-DATA-LEAKAGES.conf
RESPONSE-951-DATA-LEAKAGES-SQL.conf
RESPONSE-952-DATA-LEAKAGES-JAVA.conf
RESPONSE-953-DATA-LEAKAGES-PHP.conf
RESPONSE-954-DATA-LEAKAGES-IIS.conf
RESPONSE-959-BLOCKING-EVALUATION.conf
RESPONSE-980-CORRELATION.conf
```

We do not want to ignore the protocol attacks, but all the application stuff should be off limits. So let's kick the rules from `REQUEST-930-APPLICATION-ATTACK-LFI.conf` to `REQUEST-944-APPLICATION-ATTACK-JAVA.confa for the parameter in question`. This is effectively the rule range from 930,000 to 944,999. The script can't do rule ranges, but we can easily complement this ourselves:

```bash
# ModSec Rule Exclusion: 930000 - 944999 : All application rules for password parameters
SecRuleUpdateTargetById 930000-944999 "!ARGS:account[pass][pass1]"
SecRuleUpdateTargetById 930000-944999 "!ARGS:account[pass][pass2]"
```

Time to reduce the limit once more (down to 10!) and see what happens.

### Step 7: The fourth batch of rule exclusions

Here is the pair of logs I got after running the traffic generator once more:

* [tutorial-8-example-access-round-4.log](https://www.netnea.com/files/tutorial-8-example-access-round-4.log)
* [tutorial-8-example-error-round-4.log](https://www.netnea.com/files/tutorial-8-example-error-round-4.log)

These are the statistics:

```bash
$> cat tutorial-8-example-access-round-4.log | alscores | modsec-positive-stats.rb --incoming
INCOMING                     Num of req. | % of req. |  Sum of % | Missing %
Number of incoming req. (total) |  10000 | 100.0000% | 100.0000% |   0.0000%

Empty or miss. incoming score   |      0 |   0.0000% |   0.0000% | 100.0000%
Reqs with incoming score of   0 |   9571 |  95.7099% |  95.7099% |   4.2901%
Reqs with incoming score of   1 |      0 |   0.0000% |  95.7099% |   4.2901%
Reqs with incoming score of   2 |      0 |   0.0000% |  95.7099% |   4.2901%
Reqs with incoming score of   3 |    388 |   3.8800% |  99.5899% |   0.4101%
Reqs with incoming score of   4 |      0 |   0.0000% |  99.5899% |   0.4101%
Reqs with incoming score of   5 |     41 |   0.4100% |  99.9999% |   0.0001%

Incoming average:   0.1369    Median   0.0000    Standard deviation   0.6580
```

It seems that we are almost done. What rules are behind these remaining alerts at anomaly score 3 and 5?


```bash
$> cat tutorial-8-example-error-round-4.log  | melidmsg | sucs
     41 932160 Remote Command Execution: Unix Shell Code Found
    388 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
```

Look, the Remote Command Execution is back. What's the matter exactly?

```bash
$> cat ~/data/git/laboratory/tutorial-8/tutorial-8-example-error-round-4.log | grep 932160 | meluri | sucs
     41 /drupal/index.php/user/login
$> cat ~/data/git/laboratory/tutorial-8/tutorial-8-example-error-round-4.log | grep 932160 | melmatch | sucs
     41 ARGS:pass
```

Ah yes, that makes sense. The previous alerts were the instances where the password had been set, and here, the password is used for the login. We'll simply add this to the previous password rule exclusion:

```bash
# ModSec Rule Exclusion: 930000 - 944999 : All application rules for password parameters
SecRuleUpdateTargetById 930000-944999 "!ARGS:account[pass][pass1]"
SecRuleUpdateTargetById 930000-944999 "!ARGS:account[pass][pass2]"
SecRuleUpdateTargetById 930000-944999 "!ARGS:pass"
```

And then we're facing 942431 Restricted SQL Character Anomaly Detection again. We have done a rule exclusion for this rule on parameter `ids[]` on path `/drupal/index.php/contextual/render`. We could kick the rule completely, but given this is the remaining alert, we can also approach this with a bit more patience:

```bash
$> cat tutorial-8-example-error-round-4.log | grep 942431 | meluri  | sucs
    388 /drupal/index.php/quickedit/attachments
$> cat tutorial-8-example-error-round-4.log | grep 942431 | melmatch  | sucs
    388 ARGS:ajax_page_state[libraries]
```

So it's a single parameter again. Let's call the helper script one last time and tell it to use 10002 as the new rule ID.


```bash
$> cat tutorial-8-example-error-round-4.log | grep 942431 | \
	modsec-rulereport.rb --runtime --target --byid --baseruleid 10002
# ModSec Rule Exclusion: 942431 : Restricted SQL Character Anomaly Detection (args): # of special …
SecRule REQUEST_URI "@beginsWith /drupal/index.php/quickedit/attachments" 
	"phase:1,nolog,pass,id:10002,ctl:ruleRemoveTargetById=942431;ARGS:ajax_page_state[libraries]"
```

And with this, we are done. We have successfully fought all the false positives of a content management system with peculiar parameter formats and a ModSecurity rule set pushed to insanely paranoid levels.

I suggest you run the traffic generator again and check the output. I did and I ended up with zero alerts. This confirms that our tuning was effective and we were able to bring down the number of alerts to zero with just four relatively simple iterations.


### Step 8: Summarizing all rule exclusions

Time to look back and rearrange the configuration file with all the rule exclusions. I have regrouped them a bit, swapped the rule IDs 10001 and 10002, and I added some comments. As outlined before, it is not obvious how to arrange the rules. Here, I ordered them by ID, but also included a block where I cover the search form separately.

```bash
# === ModSec Core Rule Set: Runtime Exclusion Rules (ids: 10000-49999)

# ModSec Rule Exclusion: 942431 : Restricted SQL Character Anomaly Detection (args): …
SecRule REQUEST_URI "@beginsWith /drupal/index.php/contextual/render" \
	"phase:1,nolog,pass,id:10000,ctl:ruleRemoveTargetById=942431;ARGS:ids[]"
SecRule REQUEST_URI "@beginsWith /drupal/index.php/quickedit/attachments" \
	"phase:1,nolog,pass,id:10001,ctl:ruleRemoveTargetById=942431;ARGS:ajax_page_state[libraries]"

# ModSec Rule Exclusion: All SQLi rules for parameter keys on search form via tag attack-sqli
SecRule REQUEST_URI "@beginsWith /drupal/index.php/search/node" \
	"phase:1,nolog,pass,id:10002,ctl:ruleRemoveTargetByTag=attack-sqli;ARGS:keys"


# === ModSecurity Core Rule Set Inclusion

Include    /apache/conf/crs/rules/*.conf


# === ModSec Core Rule Set: Startup Time Rules Exclusions

# ModSec Rule Exclusion: 920273 : Invalid character in request (outside of very strict set)
SecRuleRemoveById 920273

# ModSec Rule Exclusion: 942432 : Restricted SQL Character Anomaly Detection (args): 
# number of special characters exceeded (2)
SecRuleRemoveById 942432

# ModSec Rule Exclusion: 942450 : SQL Hex Encoding Identified (severity: 5 CRITICAL)
SecRuleUpdateTargetById 942450 "!REQUEST_COOKIES"
SecRuleUpdateTargetById 942450 "!REQUEST_COOKIES_NAMES"


# ModSec Rule Exclusion: 921180 : HTTP Parameter Pollution
SecRuleRemoveById 921180


# ModSec Rule Exclusion: 930000 - 944999 : All application rules for password parameters
SecRuleUpdateTargetById 930000-944999 "!ARGS:account[pass][pass1]"
SecRuleUpdateTargetById 930000-944999 "!ARGS:account[pass][pass2]"
SecRuleUpdateTargetById 930000-944999 "!ARGS:pass"

```


### Step 9 (Goodie): Getting a quicker overview

If you do this the first time, it all looks a bit overwhelming. But then it's only been an hour of work or so, which seems reasonable - even more so if you stretch it out over multiple iterations. One thing to help you get up to speed is getting an overview of all the alerts standing behind the scores. It’s a good idea to have a look at the distribution of the scores as described above. A good next step is to get a report of how exactly the *anomaly scores* occurred, such as an overview of the rule violations for each anomaly score. The following construct generates a report like this. On the first line, we extract a list of anomaly scores from the incoming requests which actually appear in the log file. We then build a loop around these *scores*, read the *request ID* for each *score*, save it in the file `ids` and perform a short analysis for these *IDs* in the *error log*.

```bash
$> cat tutorial-8-example-access.log | alscorein | sort -n | uniq | egrep -v -E "^0" > scores
$> cat scores | while read S; do echo "INCOMING SCORE $S";\
grep -E " $S [0-9-]+$" tutorial-8-example-access.log \
| alreqid > ids; grep -F -f ids tutorial-8-example-error.log | melidmsg | sucs; echo ; done 
INCOMING SCORE 5
     30 921180 HTTP Parameter Pollution (ARGS_NAMES:op)
   3532 942450 SQL Hex Encoding Identified

INCOMING SCORE 8
      1 920273 Invalid character in request (outside of very strict set)
      1 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)

INCOMING SCORE 10
      4 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 20
     41 932160 Remote Command Execution: Unix Shell Code Found
    123 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 24
     50 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
     50 942450 SQL Hex Encoding Identified
    100 920273 Invalid character in request (outside of very strict set)
    100 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)

INCOMING SCORE 30
     76 920273 Invalid character in request (outside of very strict set)
     76 942190 Detects MSSQL code execution and information gathering attempts
     76 942200 Detects MySQL comment-/space-obfuscated injections and backtick termination
     76 942260 Detects basic SQL authentication bypass attempts 2/3
     76 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others
     76 942480 SQL Injection Attack
INCOMING SCORE 35
     76 920273 Invalid character in request (outside of very strict set)
     76 942100 SQL Injection Attack Detected via libinjection
     76 942190 Detects MSSQL code execution and information gathering attempts
     76 942200 Detects MySQL comment-/space-obfuscated injections and backtick termination
     76 942260 Detects basic SQL authentication bypass attempts 2/3
     76 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others
     76 942480 SQL Injection Attack

INCOMING SCORE 37
      5 921180 HTTP Parameter Pollution (ARGS_NAMES:ids[])
      5 942450 SQL Hex Encoding Identified
     15 920273 Invalid character in request (outside of very strict set)
     20 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)

INCOMING SCORE 74
    388 921180 HTTP Parameter Pollution (ARGS_NAMES:editors[])
    388 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
    388 942450 SQL Hex Encoding Identified
   2716 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
   3104 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 78
     76 921180 HTTP Parameter Pollution (ARGS_NAMES:keys)
     76 942100 SQL Injection Attack Detected via libinjection
     76 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
    152 942190 Detects MSSQL code execution and information gathering attempts
    152 942200 Detects MySQL comment-/space-obfuscated injections and backtick termination
    152 942260 Detects basic SQL authentication bypass attempts 2/3
    152 942270 Looking for basic sql injection. Common attack string for mysql, oracle and others
    152 942480 SQL Injection Attack
    228 920273 Invalid character in request (outside of very strict set)
INCOMING SCORE 79
      8 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
     11 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 93
     72 932160 Remote Command Execution: Unix Shell Code Found
    665 921180 HTTP Parameter Pollution (ARGS_NAMES:fields[])
    665 942450 SQL Hex Encoding Identified
   4206 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
   9113 920273 Invalid character in request (outside of very strict set)

INCOMING SCORE 144
      1 921180 HTTP Parameter Pollution (ARGS_NAMES:ids[])
      5 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
     14 920273 Invalid character in request (outside of very strict set)
     18 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)

INCOMING SCORE 171
      6 921180 HTTP Parameter Pollution (ARGS_NAMES:ids[])
      6 942450 SQL Hex Encoding Identified
     30 942431 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (6)
     96 920273 Invalid character in request (outside of very strict set)
    132 942432 Restricted SQL Character Anomaly Detection (args): # of special characters exceeded (2)
```

Before we finish with this tutorial, let me present my tuning policy again:

* Always work in blocking mode
* Highest scoring requests go first
* Work in several iterations

When you grow more proficient, you can reduce the number of iterations and tackle more false alarms in a single batch. Or you can concentrate on the rules that are triggered most often. That may work as well and in the end, when all rule exclusions are in place, you should end up with the same configuration. But in my experience, this policy with three simple guiding rules is the one with the highest chance of success and the lowest drop out rate. This is how you end up with a tight CRS setup in blocking mode with a low anomaly scoring limit.

We have now reached the end of the block consisting of three *ModSecurity tutorials*. The next one will look into setting up a *reverse proxy*.

### References
- [Spider Labs Blog Post: Exception Handling](http://blog.spiderlabs.com/2011/08/modsecurity-advanced-topic-of-the-week-exception-handling.html)
- [ModSecurity Reference Manual](https://github.com/SpiderLabs/ModSecurity/wiki/Reference-Manual)

### License / Copying / Further use

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
