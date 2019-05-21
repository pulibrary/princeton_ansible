Adding new hosts to Nginx Plus
==============================

* You will need to register the new Virtual Server at
  [https://networkregistration.princeton.edu](https://networkregistration.princeton.edu) - for now this is a bug because permission/authority is required from OIT, so
ping the #Operations Slack channel. The turn around is instant + time for DNS to
propagate worldwide.

* Generate SSL keys for the Virtual Server above. This is also another bug that
  will be fixed with a ping to the #Operations Slack channel. The turn around
  here averages about 12 hours.

* You will need at least one upstream server (for staging) and we encourage at
  least 2 for production that will host your application. This is the last bug
  that will still involve the #Operation channel. Registration for a fixed lease
  IP address is done through the network registration link in step one. The turn
  around here is also instant.

* Create your nginx configuration files for your service. Examples can be found
  at `roles/pulibrary.nginxplus/files/conf/http` for HTTP based services and
  `roles/pulibrary.nginxplus/files/conf/stream` for all others. You will need to
  use `ansible-vault` to protect any file that will be placed here.

* When the ssl files are received from OIT they will be placed under
  `roles/pulibrary.nginxplus/files/ssl` and will also need to be protected.

* Once you have your application ready you can then re-run the
  `playbooks/nginxplus.yml` playbook which will upload the new configuration
  files and ssl certificates to the production ADC and the hot-standy one and
  reload nginx.

* Tunnel into the production ADC on port 8080 to see if your new virtual server
  is available


[TODO]

* check datadog for upstream services. We have a ticket with both datadog and
  nginx plus on why the upstream services aren't showing up in our metrics
