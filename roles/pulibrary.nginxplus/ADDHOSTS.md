Adding new hosts to Nginx Plus
==============================

* You will need to register the new Virtual Server at
  [https://networkregistration.princeton.edu](https://networkregistration.princeton.edu) - for now this is a bug because permission/authority is required from OIT, so
ping the #Operations Slack channel. The turn around is instant + time for DNS to
propagate worldwide.

* What we will need is the name of the new service. If the service is to be
  example.princeton.edu, we will then register example-staging1.princeton.edu
  and example-prod1.princeton.edu, example-prod2.princeton.edu

* Where necessary generate SSL keys for the Virtual Server above. This is also another bug that
  will be fixed with a ping to the #Operations Slack channel. The turn around
  here averages about 12 hours.

* Create your nginx configuration files for your service. Examples can be found
  at `roles/pulibrary.nginxplus/files/conf/http` for HTTP based services and
  `roles/pulibrary.nginxplus/files/conf/stream` for all others. You will need to
  use `ansible-vault` to protect any file that will be placed here.

* When the ssl files are received from OIT they will be placed under
  `roles/pulibrary.nginxplus/files/ssl` and will also need to be protected.

* Once you have your application ready you can then re-run the
  `playbooks/nginxplus.yml` playbook which will upload the new configuration
  files and ssl certificates to the production ADC and the hot-standby one and
  reload nginx.

* Tunnel into the production ADC on port 8080 to see if your new virtual server
  is available
