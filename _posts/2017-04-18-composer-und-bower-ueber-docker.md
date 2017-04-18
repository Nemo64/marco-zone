---
title:      Composer und Bower über Docker ausführen
description: >
    Composer und Bower via Docker so einrichten als wären sie nativ auf dem Mac installiert.
categories: Software
date:       2017-04-18 9:00:00 +0200
---

Ich brauche im Alltag sehr oft die Abhängigkeits-Management-Tools composer und bower. Zwar lassen sich diese auf dem Mac installieren, aber irgendwie ist es doch schöner nicht alles global in irgend einen bin ordner zu werfen.

[Docker for Mac] ist eine schöne Lösung für dieses Problem. Bis vor kurzem noch duch massive Performance-Probleme geplagt ist die Beta mit der `:cached` mount option inzwischen nutzbar. So kann man diese Befehle ausführen.
 
```bash
# für composer
docker run --rm --interactive --tty -v "$(pwd):/app:cached" -w /app -v ~/.ssh:/root/.ssh -v ~/.composer:/composer:cached composer
# für bower
docker run --rm --interactive --tty -v "$(pwd):/app:cached" -w /app -v ~/.ssh:/root/.ssh digitallyseamless/nodejs-bower-grunt bower
```

Was mache ich genau?
- `--rm` sorgt dafür das der container nach der ausführung entfernt wird.
- `--interactive --tty` damit potenzielle eingaben funktionieren wie bei symfony parameters.yml zum beispiel. Sieht man auch oft abgekürzt mit `-it`.
- `-v "$(pwd):/app:cached"` mounted den aktuellen Ordner in das `/app` Verzeichnis.
- `-w /app` sorgt dafür, dass wir nach dem start auch in dem `/app` Verzeichnis sind.
- `-v ~/.ssh:/root/.ssh` hohlt uns unsere ssh keys in den container. Dies ist wichtig wenn man von privaten repositories cloned.
- `-v ~/.composer:/composer:cached` (nur composer) Dies ist der Cache-Ordner von Composer. Wenn dieser nicht definiert ist arbeitet Composer ohne Cache.
 
Nun, dies auswendig jedes mal ein zu geben ist nicht ganz so leicht, daher hab ich mir diese befehle als alias in die `~/.bash_profile` geschrieben. Linux nutzer müssten dies auch in die besser dafür geeignete `~/.bashrc` schreiben können. Dort weiß ich allerdings nicht ob es nicht zu rechteproblemen führen kann da das kommando als root läuft.
 
```bash
alias composer='docker run --rm --interactive --tty -v $(pwd):/app:cached -w /app -v ~/.ssh:/root/.ssh -v ~/.composer:/composer:cached composer'
alias bower='docker run --rm --interactive --tty -v $(pwd):/app:cached -w /app -v ~/.ssh:/root/.ssh digitallyseamless/nodejs-bower-grunt bower'
```

So kann man nun composer und bower verwenden, als wären sie nativ installiert.
 
Hier noch ein kleiner Bonus:
```bash
alias ponysay='docker run --interactive --rm mpepping/ponysay'
```

[Docker for Mac]: https://docs.docker.com/docker-for-mac/