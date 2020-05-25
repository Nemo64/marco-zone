---
title: Configure https for the official docker php apache images
description: |-
    Here is what to do to get quick and dirty https working.
categories:
    - Software-Development
date: 2020-05-25 10:50:00 +0200
image: assets/docker-moby-logo.png
---

A few days ago I finally needed to configure https in my local dev environment.
I somehow always got around it and I always heard I should test with https
but somehow never did. Since I now needed it I searched for the quickest way.

You need a `Dockerfile` to modify the official php apache image.

```sh
FROM php:7.4-apache

# install the ssl-cert package which will create a "snakeoil" keypair
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y ssl-cert \
 && rm -r /var/lib/apt/lists/*

# enable ssl module and enable the default-ssl site
RUN a2enmod ssl \
 && a2ensite default-ssl
```

And that's about it. You now just need to map port 443 to your host.

```yaml
services:
  php:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      # I map this to 443 on my host so I don't need to specify it
      - 443:443
```

{% include tldr.html content="Do not push that docker image to any repository!" %}

The nice thing about this solution is that it creates a certificate for everyone who is building the docker image.
If you put that Dockerfile into your project than everyone will have it's own unique ssl certificate.
Because of this, *you must not push that docker image* or else you'll leak your personal certificate.

More extensive guides will probably contain how you can trust that certificate
so you can avoid the browser warning but i'll ignore that for simplicity.

Another thing I want to mention are the [chialab variants of the official docker images](https://hub.docker.com/r/chialab/php).
They contain a lot of common pre installed extensions so you don't need to figure out how to install them or wait for long build.
