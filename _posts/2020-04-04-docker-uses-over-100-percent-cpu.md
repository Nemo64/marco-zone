---
title:       Docker for mac uses over 100% cpu while doing nothing
description: I use a docker for mac which has some performance problems. But it seems the interface in the background might also have some flaws.
categories:
    - Software-Development
date:        2020-04-04 20:00:00 +0200
lastmod:     2020-04-06 11:30:00 +0200
---

Today I started my mac back up after it crashed because of catalina awesome stability when it comes to external
monitors and had my fans running while i haven't started anything yet. I looked into the my processes and…

<figure>
    {% responsive_image path: 'assets/docker-high-cpu.png' alt: 'Docker uses 130% CPU' %}
</figure>

The thing is, I haven't done anything with docker yet... and normally it is hyperkit that uses 100% cpu.

So I ran the `kill -STOP` command to pause Docker:

```bash
kill -STOP $(pgrep Docker) # searches and pauses the "Docker" process
kill -CONT $(pgrep Docker) # searches and resumes the "Docker" process
```

and what happened? The docker command still runs fine, I can start projects without any problems. So what have I stopped?

Well apparently I stopped the the interface…
You know, that thing that you use once to increase the docker vm memory and to restart the docker server.

So apparently you need to keep an eye out for it and when it happens,
just pause the interface indefinitely until MacOS crashes again.


## Edits

- 2020-04-06: Use commands that you can simply copy&paste instead of having to search the process id.
