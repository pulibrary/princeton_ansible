GitLab Pages
============

GitLab Pages for our Omnibus (Linux package) GitLab CE, behind the NGINX
Plus load balancers. Staging is enabled first; production stays off
(`gitlab_pages_enabled: false` in `group_vars/gitlab/production.yml`).

Reference: <https://docs.gitlab.com/administration/pages/>

Request path
------------

GitLab today:

```text
client -> gitlab-staging.lib.princeton.edu (staging LB VIP, adc-dev1/adc-dev2)
       -> NGINX Plus :443, public cert /etc/letsencrypt/live/gitlab-staging.lib/
          (roles/nginxplus/files/conf/http/dev/gitlab_staging.conf)
       -> https://gitlab-staging-vm.lib.princeton.edu:443 (backend cert verified)
       -> Omnibus bundled NGINX -> Workhorse -> Puma
```

Pages, once enabled:

```text
client -> <Pages host> (staging LB VIP)
       -> NGINX Plus :443, public cert for the Pages host
          (roles/nginxplus/files/conf/http/dev/gitlab_pages_staging.conf)
       -> https://gitlab-staging-vm.lib.princeton.edu:8443 (backend cert verified)
          Omnibus pages_nginx vhost, allows only the staging LBs
       -> gitlab-pages daemon on localhost:8090
       -> GitLab API at external_url (through the LB) for lookups and OAuth
```

Configuration decisions
-----------------------

* **Single-domain sites** (`gitlab_pages['namespace_in_path'] = true`):
  sites are `https://pages-staging.lib.princeton.edu/<namespace>/<project>`. One DNS record and
  one ordinary certificate, no wildcard. GA in GitLab 17.4; the role
  asserts the installed `gitlab-ce` is at least `gitlab_pages_min_version`.
  With this on, wildcard URLs stop working; GitLab supports one scheme at a
  time.
* **Separate hostname**: the role refuses a Pages hostname equal to, or under,
  `gitlab_loadbalancer_domain_name`; otherwise every Pages site could read
  GitLab session cookies.
* **TLS**: public TLS terminates on NGINX Plus. The LB re-encrypts to the
  `pages_nginx` vhost on port 8443, which uses the VM's existing certbot
  certificate (`/etc/letsencrypt/live/<inventory_hostname>/`), the same as the
  main vhost. The LB verifies it with `proxy_ssl_name
  gitlab-staging-vm.lib.princeton.edu`. HTTP redirects and HSTS come from the
  LB, so `pages_nginx` has neither.
* **Binding and restriction**: `pages_nginx` listens only on the VM's primary
  IPv4 address (`gitlab_pages_nginx_listen_addresses`) and ends with
  `allow <LB>; deny all;` from `gitlab_pages_allowed_proxies`. `real_ip` is
  deliberately off on this vhost so the allow list sees the LB address, not
  the client address. The Pages daemon itself listens only on loopback.
* **Headers**: the LB passes `Host $host`, `X-Forwarded-Proto $scheme`,
  `X-Forwarded-For` and `X-Forwarded-Host`. `pages_nginx` (TLS listener) passes
  `X-Forwarded-Proto https` to the daemon.

Security caveat for single-domain sites: every project's site shares one
origin. Script published by any project runs with the same origin as every
other project's site, including access-controlled ones the viewer can open.
That is acceptable for internal docs written by staff.

Remaining decisions and values
------------------------------

| Item | Where | Status |
| --- | --- | --- |
| Staging Pages hostname | `gitlab_pages_domain_name` in `group_vars/gitlab/staging.yml` and `server_name` in the LB file | `pages-staging.lib.princeton.edu` |
| Production Pages hostname | `group_vars/gitlab/production.yml` (Pages off) | not yet set; `pages.lib.princeton.edu` proposed |
| DNS record: `pages-staging.lib.princeton.edu` -> staging LB VIP | networkregistration / OIT (see `roles/nginxplus/ADDHOSTS.md`) | done (CNAME to `adc-dev.lib.princeton.edu`) |
| Certificate `/etc/letsencrypt/live/pages-staging.lib/` on both staging LBs | LB file | done |
| Network path LB -> `gitlab-staging-vm:8443/tcp` | campus/VM firewall (not managed in this repo) | done for staging |

No change is needed to the VM certificate: the LB connects to the VM by its
own hostname.

Access control (authenticated Pages)
------------------------------------

The role sets `gitlab_pages['access_control'] = true` and
`auth_redirect_uri = https://<Pages host>/projects/auth`.

* **OAuth**: on reconfigure, Omnibus registers the Pages daemon as a system
  OAuth application (**Admin > Applications > GitLab Pages**). Its callback
  must be exactly `https://<Pages host>/projects/auth`. If it shows `http://`
  or an old hostname, remove the `gitlab_pages` section from
  `/etc/gitlab/gitlab-secrets.json` and run `gitlab-ctl reconfigure` to
  register it again. Login itself goes through GitLab, so the Entra OIDC
  auto sign-in applies; Entra needs no new redirect URI.
* **Instance setting**: after the first reconfigure, select
  **Admin > Settings > Preferences > Pages > Disable public access to Pages
  sites**. Every Pages site then requires a GitLab login, and projects lose the
  "Everyone" option.
* **Per project** (**Settings > General > Visibility, project features,
  permissions > Pages**):
  * Internal docs for all staff: project visibility **Internal**, Pages
    **Everyone With Access** (any signed-in user).
  * Restricted docs: **Private** or **Internal** project, Pages
    **Only Project Members**.
* Groups can also use **Settings > General > Permissions and group features >
  Pages public access > Remove public access** (GitLab 17.9+).

Test project
------------

Runner prerequisites:

* A runner available to the project (instance, group or project runner).
  This repository does not manage GitLab runners.
* Docker executor for the example below (`image: alpine`); with a shell
  executor, drop `image:`.
* The runner can reach `https://gitlab-staging.lib.princeton.edu` to fetch
  the job and upload artifacts.
* CI/CD and Pages are enabled for the project (on by default).

`.gitlab-ci.yml` (a job named `pages` publishing `public/` works across all
GitLab versions that support single-domain sites):

```yaml
pages:
  image: alpine:3.20
  script:
    - mkdir -p public
    - echo "<h1>GitLab Pages test $CI_COMMIT_SHORT_SHA</h1>" > public/index.html
  artifacts:
    paths:
      - public
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

After the pipeline passes, **Deploy > Pages** shows the URL. Single-domain
sites are `https://pages-staging.lib.princeton.edu/<namespace>/<project>/`. If **Use unique
domain** is selected, use the URL shown there.

Verification
------------

On `gitlab-staging-vm`:

```bash
sudo gitlab-ctl status gitlab-pages                 # run: gitlab-pages
sudo gitlab-ctl tail gitlab-pages                   # no auth/API errors
sudo ss -ltnp | grep -E ':8090|:8443'               # 127.0.0.1:8090 daemon, <VM IP>:8443 nginx
# The vhost file's location varies by GitLab version; find it by its log name.
f=$(sudo grep -rl gitlab_pages_access.log /var/opt/gitlab/nginx/conf/)
sudo grep -E 'allow|deny|listen|server_name' $f
sudo grep -E 'pages|auth' /var/opt/gitlab/gitlab-pages/gitlab-pages-config
# Pages vhost answers locally only when the LB would (expect 403 from here):
curl -sk -o /dev/null -w '%{http_code}\n' https://$(hostname -f):8443/ -H 'Host: pages-staging.lib.princeton.edu'
```

From a staging LB (allowed), the backend should answer (404 for an unknown
project is fine; 403 means the allow list is wrong):

```bash
curl -sv -o /dev/null https://gitlab-staging-vm.lib.princeton.edu:8443/ -H 'Host: pages-staging.lib.princeton.edu'
sudo nginx -t
curl -s http://127.0.0.1:8080/api/9/http/upstreams/gitlab-pages-staging | jq '.peers[] | {server,state}'
```

From a workstation:

```bash
dig +short pages-staging.lib.princeton.edu                                          # staging LB VIP
curl -sI http://pages-staging.lib.princeton.edu/                                    # 301 to https
curl -sv -o /dev/null https://pages-staging.lib.princeton.edu/ 2>&1 | grep -E 'subject|issuer|HTTP/'
openssl s_client -connect pages-staging.lib.princeton.edu:443 -servername pages-staging.lib.princeton.edu </dev/null 2>/dev/null | openssl x509 -noout -subject -dates
# Access control: an anonymous request to a restricted site redirects to the
# GitLab OAuth authorize endpoint.
curl -sI https://pages-staging.lib.princeton.edu/<namespace>/<project>/ | grep -i location
```

In a browser: open the test site signed out (expect a GitLab/Entra login,
then the page), signed in as a non-member for an "Only Project Members" site
(expect 404), and as a member (expect the page).

Troubleshooting
---------------

| Symptom | Check |
| --- | --- |
| LB 502 | `gitlab_pages_staging_error.log` on the LB; `gitlab-ctl status gitlab-pages`; port 8443 reachable from the LB; backend cert name matches `proxy_ssl_name` |
| 403 from backend for every request | LB address missing from `gitlab_pages_allowed_proxies` (see `/var/log/gitlab/nginx/gitlab_pages_error.log`) |
| 404 for a deployed site | URL must include namespace and project; check **Deploy > Pages**; `gitlab-ctl tail gitlab-pages` for domain lookup errors (the daemon calls the GitLab API through `external_url`) |
| Auth loop or `invalid redirect_uri` | **Admin > Applications > GitLab Pages** callback must be `https://<Pages host>/projects/auth`; regenerate as described above |
| `x509: certificate signed by unknown authority` in Pages logs | the daemon cannot verify GitLab's certificate; see the custom CA section of the GitLab docs |
| Role fails "GitLab Pages needs ..." | `gitlab_pages_domain_name` empty or under the GitLab hostname |
| Role fails "namespace_in_path needs GitLab ..." | upgrade GitLab before enabling Pages |

Rollback
--------

1. LB: rename `gitlab_pages_staging.conf` back to
   `gitlab_pages_staging.conf.disabled`, then run the nginxplus playbook with
   `-e nginx_cleanup_config=true`, which removes stale files (see
   `playbooks/nginxplus.yml`; not with `-t update_conf`). Or, on each LB:
   `sudo rm /etc/nginx/conf.d/gitlab_pages_staging.conf && sudo nginx -t && sudo systemctl reload nginx`.
2. GitLab: set `gitlab_pages_enabled: false` in
   `group_vars/gitlab/staging.yml` and run `playbooks/Gitlab.yml`. The Pages
   lines leave `gitlab.rb` and reconfigure stops the daemon and vhost.
   Deployed Pages content stays on disk.
3. Optional: delete the **GitLab Pages** OAuth application and the DNS record.
