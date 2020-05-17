---
language:    de
title:       Progressiver HTML Blocksatz mit Silbentrennung
description: Einige Browser unterstützen Silbentrennung über CSS. Hier ein Trick für Blocksatz wenn Silbentrennung vorhanden ist.
date:        2015-11-04 20:00:00 +0100
lastmod:     2015-11-10 12:00:00 +0100
categories:
    - Software-Development
    - HTML
redirects:
    - path: /posts/progressiver-html-blocksatz-mit-silbentrennung
    - path: /post/progressiver-html-blocksatz-mit-silbentrennung
---

Schon mal eine Zeitung gesehen und danach eine News-Seite? Das Schriftbild von Zeitungen ist meistens deutlich schöner als das von Webseiten. Woran liegt das? Mir fallen 3 Gründe ein. Einmal die meist recht hübsche Serif-Schriftart welche auf einem low-DPI Monitor allerdings furchtbar aussieht. Dann allgemein die recht niedrige Auflösung auf modernen Desktop-PC's. und zuletzt der Blocksatz, welche den Text schön gleichmäßig aussehen lässt.

## Text mit Blocksatz

*"Blocksatz können wir im Web auch!"* wird nun der eine oder andere sagen und es stimmt, `text-align: justify` erlaubt auch uns Blocksatz zu verwenden.

Das Ergebnis sieht dann so aus:

<figure>
    {% responsive_image path: 'assets/hyphans-manual.png' alt: 'Blocksatz ohne Silbentrennung' %}
</figure>

Sieht gut aus, doch wenn man anfängt den Text zu lesen, sollten die großen Abstände zwischen den Wörtern auffallen. Besonders in der deutschen Sprache haben wir zum Teil sehr lange Wörter. Der Browser darf aber nur an Leerstellen und anderen Sonderzeichen umbrechen. Damit der Blocksatz dann noch funktioniert, müssen sehr große Abstände im Text eingefügt werden.

## Text mit Blocksatz und Silbentrennung

<figure>
    {% responsive_image path: 'assets/hyphans-auto.png' alt: 'Blocksatz mit Silbentrennung' %}
</figure>

Direkt viel besser als ohne Silbentrennung! Das beste daran ist, dass es mit der css Eigenschaft [hyphens] auch mühelos in den Text eingefügt werden kann... wenn es vom Browser unterstützt wird, denn die [Browser-Unterstützung für hyphens] ist nicht sonderlich gut und wenn wir uns darauf verlassen werden einige unserer Besucher den Lückenhaften Blocksatz von oben sehen.

## Die einfachste garantiert lückenlose Implementierung

Eine neues Feature in css, das ich bisher selten gesehen hab, ist die [@supports CSS at-rule]. Das hängt vermutlich mit der [Browser-Unterstützung für @supports] zusammenhängen und dem Fakt das alle Browser, die es unterstützen, auch meistens alles können was man braucht. Desweiteren gibt es ja auch [Modernizr], welches von allen relevanten Browsern unterstützt wird.

Allerdings wird der @support Block von Browsern, die es nicht unterstützen, ignoriert und da die hyphens Eigenschaft sowieso nur von wenigen Browsern verstanden wird, ist die überschneidung von Browsern mit @supports- und hyphens support relativ groß. Daher schlage ich so etwas vor:

```css
@supports ((-webkit-hyphens: auto)
        or (   -moz-hyphens: auto)
        or (    -ms-hyphens: auto)
        or (        hyphens: auto)) {

    /*
     * Das lang Attribute ist sehr wichtig für die automatische Silbentrennung.
     * Daher erlaube ich es nur im Zusammenhang mit bestimmten Sprachen.
     * Mozilla hat eine schöne Liste mit welchen Sprachen in welchem Browser unterstützt wird:
     * https://developer.mozilla.org/en-US/docs/Web/CSS/hyphens#Browser_compatibility
     */
    [lang^=de] p,
    [lang^=en] p {
        text-align: justify;
        -webkit-hyphens: auto;
           -moz-hyphens: auto;
            -ms-hyphens: auto;
                hyphens: auto;
    }

    /*
     * Es können bestimmte Elemente in Paragrafen vor kommen
     * auf denen eine Silbentrennung nicht sehr schön ist.
     */
    a, b, abbr, strong {
        -webkit-hyphens: manual;
           -moz-hyphens: manual;
            -ms-hyphens: manual;
                hyphens: manual;
    }
}
```

## Browser-Unterstützung

Wenn wir uns die [Browser-Unterstützung für hyphens] angucken sehen wir, dass @supports von allen wichtigen Browsers unterstützt wird die [automatische hyphens unterstützten]. Allerdings gibt es 2 Ausnahmen. Der Safari unterstützt es erst seit Version 9 (und iOS 9) und der IE versteht auch kein @supports. Diese werden die at-rule einfach ignorieren und den text dann auch ohne Blocksatz anzeigen.

Was allerdings viel schlimmer ist, ist das der Chrome die hyphens Eigenschaft überhaupt nicht unterstützt. Daher muss der Text auf jeden Fall auch ohne Silbentrennung und Blocksatz gut aus sehen.

Ein weiteres Problem ist, dass die Browser alle eine andere Implementierung verwenden, welche nicht Zwangsläufig auf einem Wörterbuch basiert. W3C sagt uns:

> CSS Text Level 3 does not define the exact rules for hyphenation [...] .
> <cite>[CSS Text Module Level 3 vom 10 Oktober 2013]</cite>

Ich hab die Eigenschaft nur im Safari und Firefox getestet und dort waren die Ergebnisse identisch. Dennoch sollte man sich nicht auf eine perfekte Silbentrennung verlassen und eventuell Redakteuren die Möglichkeit geben diese für einzelne Paragraphen zu deaktivieren.

## Plattformübergreifende Silbentrennung

Eine Lösung, bereits jetzt plattformübergreifend Silbentrennung zu bieten, ist alle Wörter vorher mit `&shy;` zu trennen. Allerdings wird niemand freiwillig seinen Text mit diesen "soft hyphen" ausstatten wollen. Das Thema der automatischen Silbentrennung im Web scheint bisher auch nicht sehr verbreitet zu sein, daher gibt es nicht viele Software-Bibliotheken die man dafür verwenden kann.

Für den Browser gibt es den JavaScript-Polyfill [Hyphenator.js], welcher mit etwas Konfiguration ganz gut funktioniert. Was mir nur nicht gefällt ist, dass der Text kurzzeitig nicht sichtbar ist bis die Bibliothek die `&shy;`s eingebaut hat. Man ist außerdem an bestimmte CSS-Klassen gebunden, da der Hyphenator die CSS-Regeln nicht interpretiert.

Eine weitere Möglichkeit ist [phpHyphenator] welche scheinbar eine Portierung von [Hyphenator.js] ist. Ich hab diese allerdings bisher nicht ausprobiert und das fehlen einer Dokumentation sowie die Tatsache, dass die Bibliothek Funktionen global definiert, werden mich wahrscheinlich auch in Zukunft davon abhalten. Generell sollte jedes php Projekt zumindest mit [composer] Kompatibel sein, was dieses Projekt ebenfalls nicht ist.

## Schlusswort

Silbentrennung ist eine nette Spielerei, aber noch nicht ganz bereit für den Einsatz. Es Fehlen noch Dinge wie die Angabe wie viele Zeichen vor und nach dem Bindestich auftauchen sollen. Diese Features sind zwar im [CSS Text Module Level 4 vom 28 Oktober 2015] geplant und auch zum Teil im Safari mit `-webkit-hyphenate-limit-before/after` unterstützt, aber dann haben wir schon so viele Möglichkeiten wie die Seite aussehen kann, dass es vermutlich den Aufwand nicht wert ist. Natürlich könnte man in der @support Regel alle diese Eigenschaften als Bedingung rein kippen, aber dann gibt es das Feature aktuell nur für iPads und Safari.

[@supports CSS at-rule]: https://developer.mozilla.org/en-US/docs/Web/CSS/@supports
[Browser-Unterstützung für @supports]: http://caniuse.com/#feat=css-featurequeries
[Modernizr]: https://modernizr.com/
[hyphens]: https://developer.mozilla.org/en-US/docs/Web/CSS/hyphens
[Browser-Unterstützung für hyphens]: http://caniuse.com/#feat=css-hyphens
[CSS Text Module Level 3 vom 10 Oktober 2013]: http://www.w3.org/TR/2013/WD-css-text-3-20131010/#hyphenation
[automatische hyphens unterstützten]: http://caniuse.com/#feat=css-featurequeries
[Hyphenator.js]: http://mnater.github.io/Hyphenator/
[phpHyphenator]: http://phphyphenator.yellowgreen.de/
[composer]: https://getcomposer.org/
[CSS Text Module Level 4 vom 28 Oktober 2015]: https://drafts.csswg.org/css-text-4/#hyphenate-char-limits
