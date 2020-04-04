---
title:       Docker for mac uses over 100% cpu while doing nothing
description: I use a mac and docker is already fairly inefficient. But it seems the interface in the background might be an even worse offender. 
categories:
    - Software-Development
date:        2020-04-04 20:00:00 +0200
lastmod:     2020-04-04 20:00:00 +0200
---

Today I started my mac back up after it crashed because of catalina awesome stability when it comes to external
monitors and had my fans running while i haven't started anything yet. I looked into the my processes and…

<figure>
    {% responsive_image path: 'assets/docker-high-cpu.png' alt: 'Docker uses 130% CPU' %}
</figure>

The thing is, I haven't done anything with docker yet... and normally it is hyperkit that uses 100% cpu.

So I ran this command

```bash
kill -STOP 693 # pauses the process 693 which is docker in my case
```

and what happened? The docker command still runs fine, I can start projects without any problems. So what have I stopped?

Well apparently I stopped the the interface…
You know, that thing that you use once to increase the docker vm memory and to restart the docker server.

So apparently you need to keep an eye out for it and when it happens,
just pause the interface indefinitely until MacOS crashes again.
