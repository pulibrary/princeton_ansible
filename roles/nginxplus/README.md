Role Name
=========

nginxplus

**Note** We copied [https://github.com/nginxinc/ansible-role-nginx](https://github.com/nginxinc/ansible-role-nginx), then removed things we don't use to simplify it. All credit goes to NGINX for writing the upstream role. 

fail2ban
========

Nobody in the VPN gets blocked, thanks to our nginx
load balancer rate-limit configuration.

* To see which IPs are currently banned: `sudo ufw status`
* To see which IPs are banned due to a certain fail2ban rule: `sudo fail2ban-client status nginx-limit-req`
* To unban an IP: `sudo fail2ban-client unban [IP address]`, for example, if the IP address is 123.123.123.456, run `sudo fail2ban-client unban 123.123.123.456`.
* To manually ban an IP permanently from all load-balanced resources: `sudo ufw deny from [IP address]` (this step would need to be repeated on both load balancers)

Note that ufw needs to have at least one rule for the fail2ban
integration to work.  We have a permanent REJECT rule for traffic
from 192.0.2.0 (which is a reserved IP for special use that
will never actually send us any traffic) for this reason, do not delete this rule please.

## Testing a fail2ban rule

You can use the `fail2ban-regex` command to test your rule to make sure the regular expression syntax is correct.  You can do this on the box or (if you download a selection of the log files and `brew install fail2ban`) locally.  These commands don't ban anyone, they just check your regular expressions for correctness.

To do this:

1. Copy a representative sample of the log you want to check (otherwise it will take forever!).  For example, if you want the last 5000 lines of the nginx access log, you can `tail -n 5000 /var/log/nginx/access.log > ~/partial-access-log-for-testing`
2. Identify the filename that contains the regular expression you want to check.  In this case, we will use `/etc/fail2ban/filter.d/nginx-badbots.conf`
3. Run `fail2ban-regex ~/partial-access-log-for-testing /etc/fail2ban/filter.d/nginx-badbots.conf`
4. In the results, you can see how many hits you got in a line like `Failregex: 325 total`

Using this role
===============

* The `nginxplus` role installs NGINX Open Source and NGINX Plus on a target host. By default it expects Ubuntu. Two main playbooks use this role:
  * The `nginx_production_rebuild.yml` playbook builds new NGINX Plus load balancers from scratch.
  * The `nginx_production.yml` playbook updates existing NGINX Plus load balancers.

When updating existing load balancers, best practice is to run on a single host with `-limit`.

Adding hosts
------------

* To add a new host to the load balancers, you need to do more than just run this role. See the [Add Hosts Guide](ADDHOSTS.md) for details.

Updating SSL or configuration with tags: quick focused updates
--------------------------------------------------------------

The two tags in this role let you run subsets of its actions, so you can quickly update the load balancer in specific ways.

  * The `SSL` tag adds or updates SSL Certs and Keys. To use it:
    - add the new cert and key to the `files/ssl/` directory
    - run the `nginx_production.yml` playbook with `-t SSL` (this runs tasks with `tags: SSL` and tasks with `tags: always`)

  * The `update_conf` tag updates configuration for existing sites. To use it:
    - add the configuration file to the `files/html/` directory
    - run the `nginx_production.yml` playbook with `-t update_conf` (this runs tasks with `tags: update_conf` and tasks with `tags: always`)


Requirements
------------

This role was developed using Ansible 2.4.0.0. Backwards compatibility is not guaranteed.


Role Variables
--------------

This role has multiple variables. The defaults for all these variables are the following:

```yaml
---
# Install NGINX.
# Default is true.
nginx_enable: true

# Start NGINX service.
# Default is true.
nginx_start: true

# Print NGINX configuration file to terminal after executing playbook.
nginx_debug_output: false

# Specify which version of NGINX you want to install.
# Options are 'opensource' or 'plus'.
# Default is 'opensource'.
nginx_type: opensource

# Specify repository origin for NGINX Open Source.
# Options are 'nginx_repository' or 'os_repository'.
# Only works if 'nginx_type' is set to 'opensource'.
# Default is nginx_repository.
nginx_install_from: nginx_repository

# Choose where to fetch the NGINX signing key from.
# Default is the official NGINX signing key host.
# nginx_signing_key: http://nginx.org/keys/nginx_signing.key

# Specify source repository for NGINX Open Source.
# Only works if 'install_from' is set to 'nginx_repository'.
# Defaults are the official NGINX repositories.
nginx_repository:
  alpine: >-
      https://nginx.org/packages/{{ (nginx_branch == 'mainline')
      | ternary('mainline/', '') }}alpine/v{{ ansible_distribution_version | regex_search('^[0-9]+\\.[0-9]+') }}/main
  debian:
    - >-
      deb https://nginx.org/packages/{{ (nginx_branch == 'mainline')
      | ternary('mainline/', '') }}{{ ansible_distribution | lower }}/ {{ ansible_distribution_release }} nginx
    - >-
      deb-src https://nginx.org/packages/{{ (nginx_branch == 'mainline')
      | ternary('mainline/', '') }}{{ ansible_distribution | lower }}/ {{ ansible_distribution_release }} nginx
  redhat: >-
      https://nginx.org/packages/{{ (nginx_branch == 'mainline')
      | ternary('mainline/', '') }}{{ (ansible_distribution == "RedHat")
      | ternary('rhel', 'centos') }}/{{ ansible_distribution_major_version }}/$basearch/
  suse: >-
      https://nginx.org/packages/{{ (nginx_branch == 'mainline')
      | ternary('mainline/', '') }}sles/{{ ansible_distribution_major_version }}

# Specify which branch of NGINX Open Source you want to install.
# Options are 'mainline' or 'stable'.
# Only works if 'install_from' is set to 'nginx_repository'.
# Default is mainline.
nginx_branch: mainline

# Location of your NGINX Plus license in your local machine.
# Default is the files folder within the NGINX Ansible role.
nginx_license:
  certificate: license/nginx-repo.crt
  key: license/nginx-repo.key

# Delete NGINX Plus license after installation for security purposes.
# Default is true.
nginx_delete_license: true

# Install NGINX JavaScript, Perl, ModSecurity WAF (NGINX Plus only), GeoIP, Image-Filter, RTMP Media Streaming, and/or XSLT modules.
# Default is false.
nginx_modules:
  njs: false
  perl: false
  waf: false
  geoip: false
  image_filter: false
  rtmp: false
  xslt: false

# Install NGINX Amplify.
# Use your NGINX Amplify API key.
# Requires access to either the NGINX stub status or the NGINX Plus REST API.
# Default is null.
nginx_amplify_enable: false
nginx_amplify_api_key: null

# Install NGINX Controller.
# Use your NGINX Controller API key and NGINX Controller API endpoint.
# Requires NGINX Plus and write access to the NGINX Plus REST API.
# Default is null.
nginx_controller_enable: false
nginx_controller_api_key: null
nginx_controller_api_endpoint: null

# Install NGINX Unit and NGINX Unit modules.
# Use a list of supported NGINX Unit modules.
# Default is false.
nginx_unit_enable: false
nginx_unit_modules: null

# Remove previously existing NGINX configuration files.
# Use a list of paths you wish to remove.
# Default is false.
nginx_cleanup_config: false
nginx_cleanup_config_path:
  - /etc/nginx/conf.d

# Enable uploading NGINX configuration files to your system.
# Default for uploading files is false.
# Default location of files is the files folder within the NGINX Ansible role.
# Upload the main NGINX configuration file.
nginx_main_upload_enable: false
nginx_main_upload_src: conf/nginx.conf
nginx_main_upload_dest: /etc/nginx/
# Upload HTTP NGINX configuration files.
nginx_http_upload_enable: false
nginx_http_upload_src: conf/http/*.conf
nginx_http_upload_dest: /etc/nginx/conf.d/
# Upload Stream NGINX configuration files.
nginx_stream_upload_enable: false
nginx_stream_upload_src: conf/stream/*.conf
nginx_stream_upload_dest: /etc/nginx/conf.d/
# Upload HTML files.
nginx_html_upload_enable: false
nginx_html_upload_src: www/*
nginx_html_upload_dest: /usr/share/nginx/html
# Upload SSL certificates and keys.
nginx_ssl_upload_enable: false
nginx_ssl_crt_upload_src: ssl/*.crt
nginx_ssl_crt_upload_dest: /etc/ssl/certs/
nginx_ssl_key_upload_src: ssl/*.key
nginx_ssl_key_upload_dest: /etc/ssl/private/

# Enable creating dynamic templated NGINX HTML demo websites.
nginx_html_demo_template_enable: false
nginx_html_demo_template:
  default:
    template_file: www/index.html.j2
    html_file_name: index.html
    html_file_location: /usr/share/nginx/html
    web_server_name: Default

# Enable creating dynamic templated NGINX configuration files.
# Defaults are the values found in a fresh NGINX installation.
nginx_main_template_enable: false
nginx_main_template:
  template_file: nginx.conf.j2
  conf_file_name: nginx.conf
  conf_file_location: /etc/nginx/
  user: nginx
  worker_processes: auto
  error_level: warn
  worker_connections: 1024
  http_enable: true
  http_settings:
    keepalive_timeout: 65
    cache: false
    rate_limit: false
    keyval: false
  stream_enable: false
  http_global_autoindex: false
  #auth_request_http: /auth
  #auth_request_set_http:
    #name: $auth_user
    #value: $upstream_http_x_user

# Enable creating dynamic templated NGINX HTTP configuration files.
# Defaults will not produce a valid configuration. Instead they are meant to showcase
# the options available for templating. Each key represents a new configuration file.
nginx_http_template_enable: false
nginx_http_template:
  default:
    template_file: http/default.conf.j2
    conf_file_name: default.conf
    conf_file_location: /etc/nginx/conf.d/
    listen:
      listen_localhost:
        ip: localhost # Wrap in square brackets for IPv6 addresses
        port: 8081
        opts: [] # Listen opts like http2 which will be added (ssl is automatically added if you specify 'ssl:').
    server_name: localhost
    include_files: []
    error_page: /usr/share/nginx/html
    root: /usr/share/nginx/html
    https_redirect: false
    autoindex: false
    auth_basic: null
    auth_basic_user_file: null
    try_files: $uri $uri/index.html $uri.html =404
    #auth_request: /auth
    #auth_request_set:
      #name: $auth_user
      #value: $upstream_http_x_user
    client_max_body_size: 1m
    proxy_hide_headers: [] # A list of headers which shouldn't be passed to the application
    add_headers:
      strict_transport_security:
        name: Strict-Transport-Security
        value: max-age=15768000; includeSubDomains
        always: true
      #header_name:
        #name: Header-X
        #value: Value-X
        #always: false
    ssl:
      cert: /etc/ssl/certs/default.crt
      key: /etc/ssl/private/default.key
      dhparam: /etc/ssl/private/dh_param.pem
      protocols: TLSv1 TLSv1.1 TLSv1.2
      ciphers: HIGH:!aNULL:!MD5
      prefer_server_ciphers: true
      session_cache: none
      session_timeout: 5m
      disable_session_tickets: false
      trusted_cert: /etc/ssl/certs/root_CA_cert_plus_intermediates.crt
      stapling: true
      stapling_verify: true
    web_server:
      locations:
        default:
          location: /
          include_files: []
          proxy_hide_headers: [] # A list of headers which shouldn't be passed to the application
          add_headers:
            strict_transport_security:
              name: Strict-Transport-Security
              value: max-age=15768000; includeSubDomains
              always: true
            #header_name:
              #name: Header-X
              #value: Value-X
              #always: false
          html_file_location: /usr/share/nginx/html
          html_file_name: index.html
          autoindex: false
          auth_basic: null
          auth_basic_user_file: null
          try_files: $uri $uri/index.html $uri.html =404
          #auth_request: /auth
          #auth_request_set:
            #name: $auth_user
            #value: $upstream_http_x_user
          client_max_body_size: 1m
          #returns:
            #return302:
              #code: 302
              #url: https://sso.somehost.local/?url=https://$http_host$request_uri
      http_demo_conf: false
    reverse_proxy:
      proxy_cache_path:
        - path: /var/cache/nginx/proxy/backend
          keys_zone:
            name: backend_proxy_cache
            size: 10m
          levels: "1:2"
          max_size: 10g
          inactive: 60m
          use_temp_path: true
      proxy_temp_path:
        path: /var/cache/nginx/proxy/temp
      proxy_cache_lock: true
      proxy_cache_min_uses: 5
      proxy_cache_revalidate: true
      proxy_cache_use_stale:
        - error
        - timeout
      proxy_ignore_headers:
        - Expires
      locations:
        backend:
          location: /
          include_files: []
          proxy_hide_headers: [] # A list of headers which shouldn't be passed to the application
          add_headers:
            strict_transport_security:
              name: Strict-Transport-Security
              value: max-age=15768000; includeSubDomains
              always: true
            #header_name:
              #name: Header-X
              #value: Value-X
              #always: false
          proxy_connect_timeout: null
          proxy_pass: http://backend
          #rewrite: /foo(.*) /$1 break
          #proxy_pass_request_body: off
          proxy_set_header:
            header_host:
              name: Host
              value: $host
            header_x_real_ip:
              name: X-Real-IP
              value: $remote_addr
            header_x_forwarded_for:
              name: X-Forwarded-For
              value: $proxy_add_x_forwarded_for
            header_x_forwarded_proto:
              name: X-Forwarded-Proto
              value: $scheme
            #header_upgrade:
              #name: Upgrade
              #value: $http_upgrade
            #header_connection:
              #name: Connection
              #value: "Upgrade"
            #header_random:
              #name: RandomName
              #value: RandomValue
          #internal: false
          #proxy_store: off
          #proxy_store_acccess: user:rw
          proxy_read_timeout: null
          proxy_ssl:
            cert: /etc/ssl/certs/proxy_default.crt
            key: /etc/ssl/private/proxy_default.key
            trusted_cert: /etc/ssl/certs/proxy_ca.crt
            protocols: TLSv1 TLSv1.1 TLSv1.2
            ciphers: HIGH:!aNULL:!MD5
            verify: false
            verify_depth: 1
            session_reuse: true
          proxy_cache: frontend_proxy_cache
          proxy_temp_path:
            path: /var/cache/nginx/proxy/backend/temp
          proxy_cache_lock: false
          proxy_cache_min_uses: 3
          proxy_cache_revalidate: false
          proxy_cache_use_stale:
            - http_403
            - http_404
          proxy_ignore_headers:
            - Vary
            - Cache-Control
          proxy_cookie_path:
            path: /web/
            replacement: /
          proxy_buffering: false
          proxy_http_version: 1.0
          websocket: false
          auth_basic: null
          auth_basic_user_file: null
          try_files: $uri $uri/index.html $uri.html =404
          #auth_request: /auth
          #auth_request_set:
            #name: $auth_user
            #value: $upstream_http_x_user
          #returns:
            #return302:
              #code: 302
              #url: https://sso.somehost.local/?url=https://$http_host$request_uri
      health_check_plus: false
    proxy_cache:
      proxy_cache_path:
        path: /var/cache/nginx
        keys_zone:
          name: one
          size: 10m
      proxy_temp_path:
        path: /var/cache/nginx/proxy
    upstreams:
      upstream1:
        name: backend
        lb_method: least_conn
        zone_name: backend_mem_zone
        zone_size: 64k
        sticky_cookie: false
        servers:
          server1:
            address: localhost
            port: 8081
            weight: 1
            health_check: max_fails=1 fail_timeout=10s
    returns:
      return301:
        location: /
        code: 301
        value: http://$host$request_uri
      return404:
        location: /setup
        code: 404

# Enable NGINX status data.
# Will enable 'stub_status' in NGINX Open Source and 'status' in NGINX Plus.
# Default is false.
nginx_status_enable: false
nginx_status_port: 8080

# Enable NGINX Plus REST API, write access to the REST API, and NGINX Plus dashboard.
# Requires NGINX Plus.
# Default is false.
nginx_rest_api_enable: false
nginx_rest_api_src: http/api.conf.j2
nginx_rest_api_location: /etc/nginx/conf.d/api.conf
nginx_rest_api_port: 8080
nginx_rest_api_write: false
nginx_rest_api_dashboard: false

# Enable creating dynamic templated NGINX stream configuration files.
# Defaults will not produce a valid configuration. Instead they are meant to showcase
# the options available for templating. Each key represents a new configuration file.
nginx_stream_template_enable: false
nginx_stream_template:
  default:
    template_file: stream/default.conf.j2
    conf_file_name: default.conf
    conf_file_location: /etc/nginx/conf.d/stream/
    network_streams:
      default:
        listen_address: localhost
        listen_port: 80
        udp_enable: false
        include_files: []
        proxy_pass: backend
        proxy_timeout: 3s
        proxy_connect_timeout: 1s
        proxy_protocol: false
        proxy_ssl:
          cert: /etc/ssl/certs/proxy_default.crt
          key: /etc/ssl/private/proxy_default.key
          trusted_cert: /etc/ssl/certs/proxy_ca.crt
          protocols: TLSv1 TLSv1.1 TLSv1.2
          ciphers: HIGH:!aNULL:!MD5
          verify: false
          verify_depth: 1
          session_reuse: true
        health_check_plus: false
    upstreams:
      upstream1:
        name: backend
        lb_method: least_conn
        zone_name: backend
        zone_size: 64k
        sticky_cookie: false
        servers:
          server1:
            address: localhost
            port: 8080
            weight: 1
            health_check: max_fails=1 fail_timeout=10s

```


Dependencies
------------

None

Example Playbook
----------------

This is a sample playbook file for deploying the localhost and installing the open source version of NGINX.

```yaml
---
- hosts: localhost
  become: true
  roles:
    - role: nginxplus
```

License
-------

Apache

Author Information
------------------

Alessandro Fael Garcia,
Francis Kayiwa (removed other OS'es and NGINX Premium Products)
