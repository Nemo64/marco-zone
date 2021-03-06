---
language:   de
title:      Composer und Bower über Docker ausführen
description: >
    Composer und Bower via Docker so einrichten als wären sie nativ auf dem Mac installiert.
categories:
    - Software-Development
    - PHP
    - JavaScript
date:       2017-04-18 9:00:00 +0200
lastmod:    2017-09-09 17:41:00 +0200
---

Ich brauche im Alltag sehr oft die Abhängigkeits-Management-Tools composer und bower. Zwar lassen sich diese auf dem Mac installieren, aber irgendwie ist es doch schöner nicht alles global in irgend einen bin ordner zu werfen.

[Docker for Mac] ist eine schöne Lösung für dieses Problem. Bis vor kurzem noch duch massive Performance-Probleme geplagt ist die Beta mit der `:cached` mount option inzwischen nutzbar. So kann man diese Befehle ausführen.
 
```bash
# für composer
docker run --rm -it -v "$(pwd):/app:cached" -w /app -v ~/.ssh:/root/.ssh -v /tmp:/tmp:cached composer
# für bower
docker run --rm -it -v "$(pwd):/app:cached" -w /app -v ~/.ssh:/root/.ssh digitallyseamless/nodejs-bower-grunt bower
```

Was mache ich genau?
- `--rm` sorgt dafür das der container nach der ausführung entfernt wird.
- `-it` (ausgeschrieben `--interactive --tty`) damit potenzielle eingaben funktionieren wie bei symfony parameters.yml zum beispiel.
- `-v "$(pwd):/app:cached"` mounted den aktuellen Ordner in das `/app` Verzeichnis des Containers. Man beachte hier die `:cached` Option welche erst seit [Docker 2017-04-06-edge] verfügbar ist. Es sollte aber auch mit älteren Verisonen funktionieren, wenn diese Option nicht übergeben wird.
- `-w /app` sorgt dafür, dass wir nach dem start auch in dem `/app` Verzeichnis sind.
- `-v ~/.ssh:/root/.ssh` hohlt uns unsere ssh keys in den container. Dies ist wichtig wenn man von privaten repositories cloned. Hier hab ich die `:cached` option weg gelassen da hier io minimal sein dürfte. Dazu sei noch gesagt das dieser Mount mit den Vm-Implementationen (docker-toolbox) bei mir nicht funktioniert hat.
- `-v /tmp:/tmp:cached` (nur composer) Composer nutzt den tmp ordner als Cache. Außerdem wird hier die `auth.json` abgelegt wenn composer über das github api limit geht. Hier erwarte ich wieder mehr io, weshalb ich `:cached` wieder definiert habe.
 
Nun, dies auswendig jedes mal ein zu geben ist nicht ganz so leicht, daher hab ich mir diese Befehle als Alias in die `~/.bash_profile` geschrieben.
 
```bash
alias composer='docker run --rm -it -v $(pwd):/app:cached -w /app -v ~/.ssh:/root/.ssh -v ~/.composer:/tmp/cached:cached composer'
alias bower='docker run --rm -it -v $(pwd):/app:cached -w /app -v ~/.ssh:/root/.ssh digitallyseamless/nodejs-bower-grunt bower'
```

So kann man nun composer und bower verwenden, als wären sie nativ installiert.

Linux nutzer müssten dies auch in die besser dafür geeignete `~/.bashrc` schreiben können. Dort weiß ich allerdings nicht ob es nicht zu Rechteproblemen führen kann da der Befehl als root läuft und auch als 0 schreibt. Eventuell muss ich dann nochmal nachbessern.
 
Hier noch ein kleiner Bonus:
```bash
alias ponysay='docker run --interactive --rm mpepping/ponysay'
```

- **edit** vom 31 August 2017: Der cache ordner vom composer befindet sich nun in `/tmp/cache` 
- **edit** vom 8 September 2017: Ich hab nun den gesamten `/tmp` Order für composer frei gegeben da dort auch `auth.json` drin liegt. 

[Docker for Mac]: https://docs.docker.com/docker-for-mac/
[Docker 2017-04-06-edge]: https://docs.docker.com/docker-for-mac/release-notes/#docker-community-edition-17040-ce-mac7-2017-04-06-edge
