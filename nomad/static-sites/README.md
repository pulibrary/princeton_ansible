# Static Sites

We have a few static sites that we host on Nomad. This repository deploys a job which fetches those static sites from Github and makes them available to the load balancer.

It pulls the latest nginx image on re-deploy, and since all of our boxes restart every week for security patches, forcing a re-deploy, those images should get continuously updated.

## Sites Hosted

### Davies Project

Github: https://github.com/pulibrary/davies_project
Staging: https://daviesproject-staging.lib.princeton.edu
Production: https://daviesproject.princeton.edu

### Players & Painted Stage Milberg Exhibit Archive

Github: https://github.com/pulibrary/milberg_exhibit_archive
Staging: https://milberg-staging.lib.princeton.edu
Production: https://milberg.princeton.edu

### Digital Cicognara Library

Github: https://github.com/pulibrary/digital-cicognara-library
Staging: https://cicognara-staging.lib.princeton.edu
Production: https://cicognara.org
