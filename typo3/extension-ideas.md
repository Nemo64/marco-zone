---
layout:     text
title: Typo3 Extension Ideen
noindex: true
---

# Einige Typo3 Erweiterungs Ideen

Ich arbeite jeden Tag mit Typo3 und stolper daher ständig über fehlende Funktionen die man eigentlich erwartet. Eventuell baue ich diese mal als extension aber zur dokumentation schreibe ich sie hier auf.

## ProcedureCommandController

Häufig, wenn ich einen CommandController baue, ist dieser nicht einfach nur ein Command sondern ein importer, email versender etc.
Diese Jobs will ich dann im scheduler ausführen. Das Problem: es gibt dann keine dokumentation ob der job gelaufen ist und auch die ausgabe des commands läuft ins leere.

Meine Idee ist es einen speziellen ProcedureCommandController zu bauen welcher kein `$this->output` hat, sondern nur ein `$this->logger`.
Dies ist dann ein psr LoggerInterface. Dahinter würde ich dann einen speziellen Logger bauen der mehrere Dinge tut.

- In eine Tabelle (zb. `tx_procedure_run`) einen Eintrag anlegen gruppiertbar nach Ausführung damit die Ausführung des Tasks nachvollziehbar ist.
- Die Log-Meldungen an and Typo3's Logger weitergeben
- Die Log-Meldungen in den Command output weiterreichen. Dies kann sehr elegant gelöst werden mit verschiedenen verbositätsleveln die dann "notice", "info" und "debug" weiterreichen wenn zutreffend.

Natürlich muss das alles dann auch Fehlertollerant werden und auch typo3 typische vorgehensweisen wie `exit()` unterstützen.

## Gutes Logging

Die Logging Situation in typo3 ist ... unvollständig. Es gibt syslog, welches scheinbar nie verwendet wird, und es gibt den LogManager. Der LogManager scheint der aktuellere Weg zu sein aber kaum jemand verwendet diesen. Die standart configuration ist ok, warnungen werden in eine Datei geloggt und plugin exceptions landen auch darin. Soweit so gut.

Was fehlt sind anständige LogWriter. Es gibt keinen EmailWriter, von Fortgeschrittenden Writern in zB. Slack mal zu schweigen.
Meine Idee wäre es hier einen `MonologAdapterWriter` zu definieren. Das würde schlagartig alle Adapter von Monolog freischalten.

Dann wäre da noch das Problem das extbase nichts loggt. Ich würde mir wünschen das Änderungen an extbase Objekten zumindest im Logger auftauchen. Premium wäre natürlich wenn änderungen durch extbase im ganz normalem history modul von typo3 auftauchen würden aber ich hab da mal rein geguckt und das wird glaube ich nicht einfach.

Und da es sich um ein logger mit gewichtung handelt... warum nicht einfach alles mit debug loggen. Pluginaufrufe, SQL etc. Das könnte einem auch eine grobe echtzeitvorstellung geben was typo3 eigentlich die ganze zeit macht wenn man eine Seite aufruft.

# cHash utility

Der cHash mechanismus von typo3 wirkt auf mich undurchdacht. Also parameter werden alle fürs caching ignoriert solang es keinen cHash gibt. Ruft man also eine news detail seite mit den nötigen parametern auf ohne cHash funktioniert dies und die seite wird gecached. Wenn man die parameter nun ändert passiert nichts da typo3 die parameter änderung ignoriert.

Ich sehe dort einige große Probleme. Wenn eine Seite kalt aufgerufen wird, sind die Parameter relevant. Das kann große debug probleme hervorrufen die sich zwar schnell durch ein Cache löschen beheben lassen aber super nervig sind da man diese meist nicht reproduzieren kann. Zum anderen kann es erhebliche Sicherheitsprobleme geben. Sollte ein parameter aus irgend einem Grund unescaped auf der Seite ausgeeben werden kann das Ergebnis gecached werden und andere Nutzer die die Seite später aufrufen bekommen dann potenziell Scripte untergeschoben.

Folgendes will ich haben: Wenn kein cHash vorhanden ist müssen alle Parameter die nicht explizit aus dem cHash excludiert werden aus `$_GET` entfernt werden.

Was sich dann auch noch anbietet ist einen canonical url utility. Im endeffekt will ich eine url aus `TSFE:cHash_array` generieren können.
