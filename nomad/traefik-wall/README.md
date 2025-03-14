# Traefik Wall

This is a reverse proxy which sits between our load balancer and some of our applications and presents a Cloudflare Turnstile challenge to misbehaved bots.

```mermaid
---
title: "Network Diagram"
---
sequenceDiagram
  actor Bot
  participant N as nginx
  participant C as consul
  participant T as traefik
  participant P as passenger(rails)
  Bot->>N: Request /catalog?f[]
  N-)C: Find Traefik Node IP & Port
  C--)N: Return Traefik Node IP & Port
  N->>T: Request /catalog?f[]
  alt Bot IP range sent 20 requests in the past day
    T-->>N: Return Challenge Page
    N-->>Bot: Return Challenge Page
  else Bot IP range isn't being challenged
    T->>P: Request /catalog?f[]
    P-->>T: Return /catalog?f[]
    T-->>N: Return /catalog?f[]
    N-->>Bot: Return /catalog?f[]
  end
```

## Deployment

From `nomad` directory: `BRANCH=main ./bin/deploy traefik-wall staging`

You can track progress and status of nomad apps by looking at the Nomad UI, accessible from `./bin/login`

## Tracking Challenges

You can track what challenges are happening by looking at our load balancer's logs for the `/challenge` route:

[Datadog Challenge Logs](https://app.datadoghq.com/logs?query=service%3Aadc%20%23challenged%3A%22%2Fchallenge%22&agg_m=count&agg_m_source=base&agg_t=count&calculated_fields=challenged%3Dsplit_before%28%40uri%5C%2C%22%3F%22%5C%2C0%29&clustering_pattern_field_path=%40uri&cols=host%2Cservice%2C%23challenged&fromUser=true&messageDisplay=inline&refresh_mode=sliding&storage=hot&stream_sort=desc&viz=stream&from_ts=1740689020346&to_ts=1740692620346&live=true)

You can see all requests that still get through to an application by looking at the Passenger logs in Datadog and filtering by service. Below is an example for Latin American Ephemera.

[Datadog Passenger Logs](https://app.datadoghq.com/logs?query=source%3Anginx%20%40http.method%3AGET%20-%40http.useragent%3A%28%22nginx%2F1.27.2%20%28health%20check%29%22%20OR%20%22checkmk-active-httpv2%2F2.3.0%22%29%20service%3Alae&agg_m=count&agg_m_source=base&agg_t=count&clustering_pattern_field_path=message&cols=host%2Cservice&messageDisplay=inline&refresh_mode=sliding&storage=hot&stream_sort=desc&viz=stream&from_ts=1741108503749&to_ts=1741194903749&live=true)

You can track successful user turnstile challenges from the logs by finding all requests that hit passenger with a referer from `/challenge`:

[Datadog Challenge Success Logs](https://app.datadoghq.com/logs?query=source%3Anginx%20%40http.method%3AGET%20-%40http.useragent%3A%28%22nginx%2F1.27.2%20%28health%20check%29%22%20OR%20%22checkmk-active-httpv2%2F2.3.0%22%29%20challenge%20%23first_path_part%3A%22%2Fcatalo%22&agg_m=count&agg_m_source=base&agg_t=count&analyticsOptions=%5B%22line%22%2C%22dog_classic%22%2Cnull%2Cnull%2C%22value%22%5D&calculated_fields=first_path_part%3Dleft%28%40http.url_details.path%5C%2C7%29&clustering_pattern_field_path=message&cols=host%2Cservice%2C%23first_path_part&fromUser=true&messageDisplay=inline&refresh_mode=sliding&storage=hot&stream_sort=desc&viz=timeseries&from_ts=1741280267292&to_ts=1741366667292&live=true)

## When Bots Attack

In your load balancer nginx configuration for protected applications you'll see lines like:

```
server service.consul service=lowchallenge.traefik-wall-production resolve max_fails=0;
# server service.consul service=highchallenge.traefik-wall-production resolve max_fails=0;
```

If a site is under attack then you can uncomment the `highchallenge` line and comment the `lowchallenge`, reload the nginx config, and all visits will be challenged, effectively taking all bot traffic off the application servers.

## Cloudflare Configuration

To view and modify the Cloudflare Turnstile configuration you can log in to [Cloudflare](https://dash.cloudflare.com/login) using access information found in LastPass.

## Special Thanks

This implementation would only be possible with the support of [joecorall](https://github.com/joecorall) for developing [captcha-protect](https://github.com/libops/captcha-protect) and [jrochkind](https://github.com/jrochkind) for testing a similar implementation for Rails applications.

Thank you.
