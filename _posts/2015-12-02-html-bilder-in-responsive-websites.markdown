---
title:          HTML Bilder in Responsive Websites
description:    Einige Ansätze Bilder in Webseiten zu verwalten, die sich an die Bildschirmgröße anpassen müssen.
image:          banner.jpeg
date:           2015-12-02 20:00:00 +0100
lastmod:        2015-12-02 20:00:00 +0100
categories:
    - Webseite
    - Bilder
---

Jeder, der schon einmal eine Webseite für mobile Geräte erstellt hat, kennt das Problem. Bilder sollen überall gut aussehen und man will nicht mehr Bandbreite verwenden als unbedingt notwendig. Die umsetzung dafür war früher ziemlich einfach: man schaut sich das Layout der Seite an, misst wie groß ein Bild in Pixeln sein muss und benutzt eine der vielen Möglichkeiten das Bild auf exakt die Größe zu skalieren.

## Ein Bild mit genauer Größe

Das genaue anpassen der Bilder funktioniert auch heute noch recht gut und benötigt so gut wie keinen Aufwand. Im einfachsten Fall strengen wir unser bevorzugtes Grafik-Programm an das Bild zu skalieren.

 - Bild wird vom Browser schneller geladen, da der [pre-loader] sie erkennt.
 - einfache Verwaltung: wir brauchen nur ein Bild.
 - Sehr einfache Deklaration im Markup.

Es wäre aber langweilig wenn es nicht Probleme gäbe:

 - Es sind nicht genug Bildinformationen für HighDPI Bildschirme vorhanden, wodurch Bilder unscharf wirken im Vergleich zum Text.
 - Wenn die Bildgröße abhängig von der Schriftgröße ist (zB. `12rem`) wird das Bild uu. leicht skaliert. Das schadet der Qualität mehr als eine stärkere Skalierung.
 - Eine variable Größe (zB. `100vw`) führt fast immer zu einer Skalierung und somit entweder in einem unscharfen Bild oder zu der Verschwendung von Bandbreite wofür dich Edge-Kinder lieben werden.
 - Es ist nicht möglich, das Bild abhängig vom verfügbarem Platz, aus zu tauschen.

Dadurch, dass es die einfachste implementierung ist, werden wir vermutlich für immer diese Implementierung sehen. Das heißt aber nicht, dass es nicht bessere gibt.

## Mehrere Bilder mit unterschiedlichen Größen

Ok, die Anzahl an Möglichkeiten ist überwältigend. Ich habe einen älteren (2012) [Artikel von CSS-Tricks] gefunden der auf viele Wege eingeht. Es gibt auch eine [schöne Tabelle] mit vielen Techniken die man verwenden kann um die richtigen Bilder aus zu liefern.

Diese Hack-Lösungen interessieren mich allerdings alle nicht! Ich möchte ein zukunftssicheres Markup haben das am besten ohne JavaScript funktioniert. Tja, um meinem Mund zu stopfen bekam ich gleich 3 native Wege dies um zu setzen.

### Das `srcset` Attribut mit `x` Angabe

```html
<img srcset="image.jpg 1x, image-2.jpg 2x, image-3.jpg 3x"
     alt="Dieses Bild ist immer scharf"
     src="image.jpg">
```

Diese Syntax erklärt sich von selbst. Wenn der Browser es unterstützt guckt er sich das srcset Attribut an und wählt anhand der `devicePixelRatio` welches Bild er lädt. Wenn der Browser es nicht unterstützt ignoriert er das `srcset` und lädt einfach das Bild in der `src`.

 - Das Bild wird vom Browser weiterhin vom pre-loader schnell geladen.
 - Das Bild wird auf HiDPI Geräten scharf sein.
 - Immer noch relativ einfache Deklaration im Markup.

Allerdings bleiben viele der negativen Punkte bestehen:

 - Bildgröße anhand der Schriftgröße kann weiterhin zu hässlichen Skalierungen führen.
 - Es bietet immer noch keine Lösung für 100% breite Banner für responsive Design.
 - Es ist nicht möglich, den Bildinhalt abhängig vom verfügbarem Platz aus zu tauschen.
 - Wir brauchen nun mehrere Bilder

Grundsätzlich haben wir also einen Negativ-Punkt ins Positive gebracht (HiDPI), aber auch einen ins Negative (Verwaltung/Mehrere Bilder). Spoiler: Alle Methoden brauchen mehrere Bilder, daher werden wir diesen Punkt nicht mehr los.

Ich erwähne diesen Weg zuerst, da er den größten [Browser-Support] hat (ios 8+). Allerdings ist dies fast irrelevant, den die erweiterte `w` Version hat nur minimal schlechteren Support (ios 9+).

Noch etwas: Ich würde das `srcset` Attribut immer zuerst deklarieren, damit der pre-loader dieses garantiert zuerst sieht. Ich weiß nicht wie gut die heutigen pre-loader sind, aber ich hoffe das ich damit einen unnötigen Anfragen sparen kann. Ob es einen Unterschied macht hab ich allerdings nicht getestet. Sollte jemand mehr wissen: gerne in die Kommentare.

### Das `srcset` Attribut mit `w` Angabe

Dieses Version hat nur minimal schlechteren [Browser-Support] als die `x` Version. Da jeder, der einen älteren Browser benutzt, die Seite dennoch problemlos sehen kann denke ich nicht, dass das ein Problem ist.

```html
<img srcset="banner-720.jpg 720w, banner-1080.jpg 1080w"
     sizes="100vw"
     alt="Dieses Bild wird perfekt ausgewählt"
     src="banner-720.jpg">
```

In dieser Version definieren wir, wie breit das Bild in Pixel ist. Der Browser wählt sich dann das Beste aus. Es gibt momentan keine Möglichkeit die Auswahl anhand der Höhe zu treffen.

Der Browser hat nur ein Problem mit diesem Weg. Er muss wissen wie groß das Bild im Layout sein wird. Da aber der Stylesheet meist nicht sofort verfügbar ist, müsste der Browser mit dem laden von dem Bild warten bis er alle CSS-Dateien geladen hat. Daher sieht der Standard ein weites Attribut vor. `sizes` definiert wie breit das Bild sein wird. Das heißt: wir müssen leider unser Layout zu einem Teil im Markup verewigen. Bei dem Banner-Beispiel ist dies noch recht einfach, aber es kann schnell kompliziert werden. Für diesem Blog benutze ich momentan für die Thumbnails diese Syntax:

```html
<img sizes="(min-width: 48em) 9rem, 3rem">
```

Damit sag ich dem Browser, dass die Thumbnails `9rem` breit sind solang die Media-Query `(min-width: 48rem)` zutrifft. Das Beispiel kann aber beliebig kompliziert werden. Hier ein paar Beispiel für Bilder in Bootstrap:

```html
<!-- Bootstrap 3 mit Container-Breite -->
<img sizes="(min-width: 1200px) 1170px, (min-width: 992px) 970px, (min-width: 768px) 750px, 100vw">
<!-- Bootstrap 3 in einer Spalte -->
<img sizes="(min-width: 1200px) 1140px, (min-width: 992px) 940px, (min-width: 768px) 720px, calc(100vw - 30px)">
<!-- Bootstrap 4 mit Container-Breite -->
<img sizes="(min-width: 75em) 72.25rem, (min-width: 62em) 60rem, (min-width: 48em) 45rem, (min-width: 34em) 34rem, 100vw">
<!-- Bootstrap 4 in einer Spalte -->
<img sizes="(min-width: 75em) 70.375rem, (min-width: 62em) 58.125rem, (min-width: 48em) 43.125rem, (min-width: 34em) 32.125rem, calc(100vw - 1.875rem)">
<!-- kleine warnung: ich hab die Angaben nicht getestet -->
```

Wie man sieht ist es möglich `calc()` zu verwenden, aber das macht die Angaben leider nur noch Aufwendiger. Wenn wir nun eine Größe in CSS ändern müssen wir auch unser Markup ändern.... unschön.

Aber lohnt es sich?

 - Das Bild wird vom Browser weiterhin vom pre-loader schnell geladen.
 - Das Bild wird auf HiDPI Geräten scharf sein.
 - Wir laden auf dem Smartphone nicht mehr unser überdimensioniertes 5120×2160 Banner.
 - `rem` und `em` werden beachtet.

Somit haben wir nun fast alle negativen Punkte, die für den Nutzer relevant sind, ins Positive gebracht. Also nun das Zähne-Knirschen für die Entwickler:

 - Wir brauchen immer noch mehrere Bilder von denen wir nun auch noch die Breite im HTML verewigen müssen.
 - Die Deklaration kann für komplizierte Layouts sehr Aufwendig werden.
 - Es ist weiterhin nicht möglich, den Bildinhalt abhängig vom verfügbarem Platz aus zu tauschen.

Dies ist somit, sofern man die Zeit im Projekt hat die Bilder zu organisieren, die beste Möglichkeit **ein** Bild in der best möglichen Größe zu laden. Das einzige, was es nicht löst, ist der austausch von dem Bild unter bestimmten Situationen. Ein kleines Bild sollte uu. einen anderen Ausschnitt zeigen im gegensatz zu einem, das auf dem Desktop in Volbild angezeigt wird. Da wir aber auf modernen Smartphones zum teil eine höhere Auflösung haben als auf einem Desktop können wir die Breite vom Bild nicht verwenden um zwischen verschiedenen Ausschnitten zu wählen.

### Das `<picture>` Element

Dieses Element kann nun auch das Problem des Bildinhaltes lösen. Ich werfe einfach direkt ein Beispiel rein:

```html
<picture>
    <source srcset="desktop-thumbnail-144.jpg 144w, desktop-thumbnail-288.jpg 288w"
            sizes="9rem"
            media="(min-width: 62em)">
    <source srcset="tablet-thumbnail-128.jpg 128w, tablet-thumbnail-256.jpg 256w"
            sizes="8rem"
            media="(min-width: 48em)">
    <img src="dektop-thumbnail-144.jpg"
         srcset="mobile-thumbnail-48.jpg 48w, mobile-thumbnail-96.jpg 96w"
         sizes="3rem"
         alt="Wunderschönes Thumbnail">
</picture>
```

Es ist möglich jeder einzelnen `<source>` eine eigene Media-Query zu geben um zu definieren wann diese zu trifft. Der Browser geht die sources in der Definitions-Reihenfolge durch und nimmt sich die Erste die zutrifft, daher fange ich mit dem Größten an. Damit erspare ich mit die merkwürdigen `(max-width: 61.9em)` Abfragen um die Bildauswahl in beide Richtungen zu limitieren. In meinen Tests scheint das `<img>`-Element auch als source ohne Media-Abfrage zu gelten. Das ist auch deshalb interessant, da das `<picture>`-Element einen noch [schlechteren Browser-Support] hat als das `srcset`-Attribut.

Diese Variante erlaubt es nun für ein kleines Layout ein anderes Bild zu verwenden, welches zum Beispiel einen kleineren Ausschnitt zeigt. Natürlich sind auch Media-Queries wie print möglich. Es ist allerdings nicht möglich das Bild in bestimmten Layouts überhaupt nicht zu laden. Eine Möglichkeit dafür wäre der klassische transparente Gif-Platzhalter.

Das `<picture>` Element hat noch einen weiteren theoretischen Vorteil. Ähnlich wie bei dem `<video>` Element kann jeder `<source>` ein `type="image/jpeg"` gegeben werden. Der Browser lädt dann diese nur, wenn er diesen Typ unterstützt. Mein erster Gedanke ging an SVG, doch jeder Browser, der `<picture>` unterstützt, sollte SVG bereits unterstützten. Das Einzige was mir noch einfallen würde ist [WebP], welches derzeit nur von Blink, also Chrome und Opera (und mobile Varianten) unterstützt wird, aber das Format ist den Aufwand einer weiteren Kodierung nicht wert... außer vielleicht wenn dringend Bandbreite gespart werden muss und eine stärkere JPEG-Kompression nicht in Frage kommt.

## Schlusswort

Mehrere Bilder in verschiedenen Größen an zu bieten ist eine super Sache um die bestmögliche Erfahrung auf allen Geräten zu bieten und da alle Varianten (die ich gezeigt hab) Rückwärts-Kompatibel sind spricht nichts dagegen diese sofort ein zu setzen. Wenn voller Browser-Support zwingend nötig ist, kann auch mit einem Polyfill wie [Picturefill] nachgeholfen werden.

Allerdings gibt es den Nachteile der komplizierteren Konfiguration und bei sehr vielen Bildern ist die Dateigröße auf dem Server auch nicht zu vernachlässigen. In meinen Tests ist es häufig schlauer das Bild in einer höheren Auflösung aus zu liefern und dafür eine niedrigere Jpeg-Qualität zu verwenden (zB. 65% anstatt 85%). Die Dateien sind dann meistens nicht viel größer als die low-DPI Variante und auf einem high-DPI Gerät ist der Unterschied kaum sichtbar. Es sieht allerdings immer noch deutlich besser aus, als ein low-DPI Bild auf einem high-DPI Gerät.

Wo es allerdings viel Sinn macht ist bei Bannern oder anderen Bildern, die ihre Größe anhand des Viewports ändern. Dort spielt häufig nicht nur die Datengröße eine Rolle, sondern auch die Skalierung vom Endgerät. Der Safari zum Beispiel erzeugt sehr schnell hässliche Treppen bei einer starken Skalierung und der Chrome erzeugt immer sehr verwaschene Bilder. Dort macht ein `srcset` sehr viel Sinn.

Und zuletzt ist für Art-Direction ein `<picture>`-Element sehr viel Wert. Allerdings kann in einigen Fällen auch eine CSS-Lösung mit Media-Abfragen sehr gut funktionieren. So eine Lösung benötigt dann auch keinen Polyfill.

[pre-loader]: http://andydavies.me/blog/2013/10/22/how-the-browser-pre-loader-makes-pages-load-faster/
[Artikel von CSS-Tricks]: https://css-tricks.com/which-responsive-images-solution-should-you-use/
[schöne Tabelle]: https://docs.google.com/spreadsheet/ccc?key=0Al0lI17fOl9DdDgxTFVoRzFpV3VCdHk2NTBmdVI2OXc#gid=0
[Browser-Support]: http://caniuse.com/#feat=srcset
[schlechteren Browser-Support]: http://caniuse.com/#feat=picture
[WebP]: https://developers.google.com/speed/webp/
[Picturefill]: https://github.com/scottjehl/picturefill