# 1. Cicognara Let's Encrypt Path

Date: 2020-02-11

## Status

Accepted

## Context

There are instances where we will be unable to use our InCommon Federation SSL certificate framework for certs. In instances where a dot org, etc., In those instances Let's Encrypt is an adequate solution. 

The Lets Encrypt expects the SSL certs to be under `/etc/letsencrypt/` which differs from where we place the rest of our SSL certificated


## Decision

make sure certificates are under `/etc/letsencrypt/`
create a directory under `/var/www/letsencrypt/<servicename>` This directory which is configured as the `http://tld.domain/.well_known` will be empty but is needed during the Let's Encrypt verification step.


## Consequences

* allow an automated cron task to run for renewal
