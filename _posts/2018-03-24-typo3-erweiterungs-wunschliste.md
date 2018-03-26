---
title:       Typo3 Erweiterungs Wunschliste
description: Eine Sammelstelle für Typo3 Erweiterungen die ich unbedingt haben will und irgendwann vielleicht auch baue.
categories:
    - Software-Entwicklung
    - Typo3
date:        2018-03-24 21:36:00 +0100
lastmod:     2018-03-26 12:20:00 +0200
---

Ich arbeite jeden Tag mit Typo3 und stolper daher ständig über Funktionen bei denen ich denke "Ich kann doch nicht der erste sein der so etwas haben will". Eventuell baue ich diese mal als extension aber zur Dokumentation schreibe ich sie hier auf.

Die Reihenfolge hat keinerlei Bedeutung, es ist einfach die Reihenfolge in der sie mir ein gefallen sind. Ich aktuallisiere diese List auch ab und zu.

## ProcedureCommandController

Häufig, wenn ich einen CommandController baue, ist dieser nicht einfach nur ein Command, sondern ein Importer, E-Mail Versender etc.
Diese Jobs will ich dann im Scheduler ausführen. Das Problem: es gibt dann keine Dokumentation ob der Job gelaufen ist und auch die Ausgabe des Commands läuft ins Leere.

Meine Idee ist es einen speziellen ProcedureCommandController zu bauen welcher kein `$this->output` hat, sondern nur ein `$this->logger`.
Dies ist dann ein psr LoggerInterface. Dahinter würde ich dann einen speziellen Logger bauen der mehrere Dinge tut.

- In eine Tabelle (zb. `tx_procedure_run`) einen Eintrag anlegen der nach Ausführung gruppiertbar ist damit die Ausführung des Tasks nachvollziehbar ist.
- Die Log-Meldungen an and Typo3's Logger weitergeben
- Die Log-Meldungen in den Command output weiterreichen. Dies kann sehr elegant gelöst werden mit verschiedenen verbositätsleveln die dann "notice", "info" und "debug" weiterreichen wenn zutreffend.

Natürlich muss das alles dann auch Fehlertolerant werden und auch typo3 typische Vorgehensweisen wie `exit()` unterstützen.
Diese Extension hängt vermutlich sehr stark mit der nächsten zusammen.

## Gutes Logging

Die Logging Situation in typo3 ist ... unvollständig. Es gibt syslog, welches scheinbar nie verwendet wird, und es gibt den LogManager. Der LogManager scheint der aktuellere Weg zu sein aber kaum jemand verwendet diesen. Auch der core selbst loggt so gut wie nichts außer fehler und diese auch nur indirekt. Die Standardkonfiguration ist ok, Warnungen werden in eine Datei geloggt und Plugin-Exceptions landen auch darin. Soweit so gut.

Was fehlt sind anständige LogWriter. Es gibt keinen EmailWriter, von fortgeschrittenden Writern in zB. Slack mal zu schweigen.
Meine Idee wäre es hier einen 'MonologAdapterWriter' zu definieren. Das würde schlagartig alle Adapter von Monolog freischalten.

Dann wäre da noch das Problem das extbase nichts loggt. Ich würde mir wünschen, dass Änderungen an extbase Objekten zumindest im Logger auftauchen. Premium wäre natürlich, wenn Änderungen durch extbase im ganz normalem history modul von typo3 auftauchen würden aber ich hab da mal rein geguckt und das wird glaube ich nicht einfach.

Und da es sich um ein logger mit Gewichtung handelt... warum nicht einfach alles mit debug loggen. Typo3 hat Hooks und Signal-Slots für so ziemlich alles. Pluginaufrufe, SQL anfragen etc.. Das könnte einem auch eine grobe Echtzeitvorstellung geben was typo3 eigentlich die ganze zeit macht, wenn man eine Seite aufruft.

## cHash utility

Der cHash Mechanismus von typo3 wirkt auf mich undurchdacht. Also Parameter werden alle fürs Caching ignoriert solang es keinen cHash gibt. Ruft man also eine News-Detail-Seite mit den nötigen Parametern auf ohne cHash funktioniert dies und die Seite wird gecached. Wenn man die Parameter nun ändert passiert nichts da typo3 die Parameter-Änderung ignoriert.

Ich sehe dort einige große Probleme. Wenn eine Seite kalt aufgerufen wird, sind die Parameter relevant. Das kann große Debug-Probleme hervorrufen, die sich zwar schnell durch ein Cache löschen beheben lassen aber super nervig sind da man diese meist nicht reproduzieren kann. Zum anderen kann es erhebliche Sicherheitsprobleme geben. Sollte ein Parameter aus irgend einem Grund unescaped auf der Seite ausgegeben werden kann das Ergebnis gecached werden und andere Nutzer, die die Seite später aufrufen, bekommen dann potenziell Scripte untergeschoben.

Folgendes will ich haben: Wenn kein cHash vorhanden ist müssen alle Parameter die nicht explizit aus dem cHash excludiert werden aus `$_GET` entfernt werden.

Was sich dann auch noch anbietet, ist einen canonical url utility. Im Endeffekt will ich eine URL aus `TSFE:cHash_array` generieren können.

## Internationalization utilities

Es gibt in php die intl extension welche Klassen wie den 'NumberFormatter' und den 'IntlDateFormatter' mitbringen. Dies sind Features die Zwingend in ViewHelper verpackt gehören. Ich habe diese ViewHelper bereits (inspiriert von der [Twig Intl Erweiterung]), ich muss sie nur noch in eine Extension auslagern.

Mir fallen aber noch mehr Funktionalitäten ein. zB. möchte ich eine Typolink-Erweiterung ein bauen die `tel:` unterstützt und mithilfe von [giggsey/libphonenumber-for-php] formatiert.

Und wenn wir schon dabei sind, [Symfony's intl polyfill], welcher als Abhängigkeit durchaus Sinn ergibt wenn die Erweiterung intl sowieso vorausgesetzt ist, [enthält auch icu Daten] womit ich einen 'CountryNameViewHelper' und einen 'LanguageNameViewHelper' implementieren kann.

## Kopieren von sys_lanugage in typoscript constanten

Ja, dazu fällt mir kein richtiger Name ein und eventuel gehört das zur Erweiterung oben.

Aktuell muss man in Typo3 jede Sprache hardcodieren und mit der Datenbank synchron halten mit so lustigen Bedingungen in typoscript wie:
```
[globalVar = GP:L=1]
config.sys_language_uid = 1 
config.language = de
config.htmlTag_langKey = de
config.locale_all = de_DE.utf8
[global]
``` 

Das heißt bei neuen sprachen muss man diese in die Datenbank hinzufügen und im typoscript etwas copy paste arbeit leisten.
Viel schöner wäre es doch wenn eine extension einem dieses typoscript generiert. Im einfachsten fall würde man einfach alle Spalten von sys_language record in typoscript constanten kopieren. Dann gibt es an jeder stelle so etwas:
- `{$sys_language.uid}`
- `{$sys_language.title}` 
- `{$sys_language.language_isocode}` 
- `{$sys_language.flag}` 

[Twig Intl Erweiterung]: http://twig-extensions.readthedocs.io/en/latest/intl.html
[giggsey/libphonenumber-for-php]: https://packagist.org/packages/giggsey/libphonenumber-for-php
[Symfony's intl polyfill]: https://packagist.org/packages/symfony/intl
[enthält auch icu Daten]: https://symfony.com/doc/current/components/intl.html#accessing-icu-data