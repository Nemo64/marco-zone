---
title:      Jira Performance optimieren durch AdBlock
description: >
    Jira ist langsam und, wie viele moderne seiten, überladen.
    Ich hab versucht Jira mit AdBlock etwas benutzbarer zu bekommen.
categories: Software
date:       2017-04-06
---

Wir versuchen auf der Arbeit aktuell mit Jira zu arbeiten. Da viele dies scheinbar verwenden hielten wir das für eine gute Idee, doch inzwischen wissen wir dass das keine dauerlösung ist. Es ist Langsam, Projekte sind schwer ein zu richten und grundlegende Funktionen wie Zeiterfassung sind unbenutzbar und können nur durch noch langsamere und unzuverlässigere Plugins überhaupt verwendet werden.
 
Also nachdem ich klar gemacht hab wie ich zu Jira stehe nun zum eigentlichen Thema. Ich hab mal geguckt warum Jira so lang zum laden braucht und eine gigantischen Anzahl an http Anfragen gefunden. Also hab ich mir den spaß gemacht und einige in adblock eingetragen und viele der Anfragen haben die Funktionalität scheinbar nicht beeinträchtigt oder sogar verbessert. Hier als meine bisherige Liste. Diese Regeln können einfach in den AdBlock Plus Einstellungen als "Eigener Filter" hinzugefügt werden.

- `*atlassian.net/secure/projectavatar*` Selbsterklärend, ich verstecke alle projektavatare und reduziere somit die Anzahl an http anfragen an den projekt domain da der browser nur eine begrenzte anzahl an anfragen an einen domain stellt.
- `*atlassian.net/rest/api/2/mypermissions*` Macht eine riesige Anzahl an Anfragen auf dem Dashboard. Scheint keinerlei auswirkungen zu haben.
- `*engage-delivery.useast.atassian.io*` Weniger wegen performance und eher um feature popups zu verhindern. Es wird zB. mit der Mobile App geworben welche legitim nicht soo schlecht ist, aber die werbung dafür ist grauenvoll nervig. Ich würde lieber sehen, das mehr Resourcen in ein gutes Webinterface gesteckt werden.
- `*atlassian.net/rest/analytics*` Auch selbsterklärend. Blockiert deren analytics und hat für einen nutzer keine nachteile, nur den performance Vorteil wegen weniger requests auf eine Domain.
- `*atlassian.net/rest/filters*` Hier werden schnellfilter nachgeladen. Wenn ihr die nicht nutzt sind die Anfragen unnötig.
- `*atlassian.net/rest/hipchat*` Ich habe hipchat nie verwendet und werde es vermutlich nie tun. Ergo unnötige http Anfragen.

Ich geb zu das der Performance unterschied jetzt nicht überwältigend ist, aber es fühlt sich irgendwie gut an so in Jira ein zu greifen und Features, bei denen Irgendwer entschieden hat das sie essentiell sind, einfach zu blockieren. Darum geht es ja eigentlich auch im AdBlock.