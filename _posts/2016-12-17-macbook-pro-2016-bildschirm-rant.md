---
title:      MacBook Pro 13" (2016) Bildschirm Rant
description: >
    Das MacBook Pro hat viele schwächen. Hier ist noch eine die mich wahnsinnig macht und scheinbar niemandem auffällt.
categories:
    - Hardware
    - Rant
    - Review
date:       2017-01-15
---

Ich hab nun Zugang zu einem MacBook Pro 13". Ich hab mir vorher die Reviews aus dem Ami-Land angeschaut und bin zu dem schluss gekommen das die Nachteile mich nicht wirklich stören. Nun gibt es aber einen Nachteil der mich stört und zwar gewalltig.

## Der Bildschirm

Hoch gelobt als "der beste Retina-Bildschirm" von Apple. Er sieht auch auf den ersten Blick super aus, aber ich arbeite an Interface Design und bin etwas Perfektionistisch was pixel perfekte bilder an geht.

Nach kurzer zeit ist es mir dann Aufgefallen.

### Das MacBook Super-Sampled

{% include tldr.html content="Der Monitor zeigt überall Skalierungs-Artefakte" %}

Das 13" Model hat eine 2560x1600 Pixel Bildschirm was eigentlich recht ordentlich ist. Leider ist das Scaling von macOS nicht fähig in Faktoren wie 1.5x oder 1.75x zu Skalieren. Das heißt, die Retina Auflösung müsste 1280x800 sein, ist sie aber nicht. Stattdessen nutzt der Rechner eine virtuelle Auflösung von 1440x900, skaliert diese durch macOS Scaling auf 2880x1800 und skaliert diese dann wieder grafisch auf die realen 2560x1600.

<figure>
    {% responsive_image path: "assets/macbook-pro-scaling-decolor.jpg" %}
</figure>

Dies Bedeutet, dass kein Pixel direkt angesprochen werden kann. Linien verschwimmen je nachdem wo sie auf dem Bildschirm sind. Text ist nicht so scharf wie er sein könnte und dann haben wir auch noch den Performance Verlust.

Warum Apple nicht einfach einen Bildschirm mit der passenden Auflösung verbaut hat ist mir schleierhaft. Ich gebe ja zu das die Skalierung dem normalen Menschen nicht auffallen wird, aber mir fällt es auf und ich möchte in einem 2000€ Notebook ein ordentliches Bild haben, besonders wenn mit dem Bildschirm geworben wird.

Aber wenn das nur alles wäre...

### Die Farbkalibrierung

Großer Farbraum gut und schön, aber meine Zeilgruppe sind nur zum Teil die paar Prozent Mac-Nutzer. Größtenteils sind es Monitore die sRGB nutzen. Das heißt: Dieser Bildschirm sollte nicht für Arbeiten mit Farbe verwendet werden. Nun, da ich beim Layout auch gerne eine akurate Pixel-Darstellung haben will habe ich quasi 2 Argumente gegen diesen Bildschirm

Es hat noch einen Nachteil. Dieser Bildschirm wird schön Hell, aber wenn man ihn mal nicht sonderlich Hell haben will, hat weiß einen deutlichen Grün-/Blaustich. Es ist unangenehm im dunkeln sich weiße Seiten an zu sehen. 

## Was Bedeutet das nun

{% include tldr.html content="Kaum einem fällt das Problem auf." %}

Ich bin ehrlich, ich lass mich hier gerade etwas aus. Der Monitor ist auf den ersten Blick echt schön und wäre es ein MacBook Air für 900€ hätte ich verstanden dass man an der Auflösung spart und es darauf trimmt bei Bildern und Filmen ein "ohh wie hübsch" Moment zu erzeugen.

Nun, es handelt sich aber um das MacBook Pro für 2000€ und ich verstehe einfach nicht wer die Zeilgruppe ist. Wer Casual im Web surft sollte sich nach etwas deutlich billigerem umsehen, selbst das 12" MacBook wäre eine alternative wenn man im Apple universum bleiben will (von Außen betrachtet hat dies allerdings die selben Probleme). Illustratoren sollten sich allgemein eher die Surface Produkte ansehen und ich als jemand der Webseiten Entwickelt bin von dem Retina Scaling geärgert.

Die einzige Zielgruppe scheint noch der Video-Schnitt markt zu sein die mit Final Cut Pro wohl gute Leistung erzielen. Es gibt wohl auch noch Musiker die auf das MacBook schwören aber mit dieser Zielgruppe kenne ich mich zu wenig aus.

## Zusammenfassung

Ich kann mit allem Leben was das Gerät auf mich wirft. Ich finde USB-C ist ein super Standart, die Touchbar kann in einigen Anwendungen sehr hilfreich werden (auch wenn Apple in ihren Apps scheinbar versucht Negativ-Beispiele zu geben), die Tastatur ist sehr Subjektiv aber ich mag sie, das Trackpad ist genial...

Mein Ergebnis wird sich von dem anderer Reviews nicht unterscheiden. Kauft euch das Gerät nicht mit dem Gedanken das es ein Upgrade oder Ähnliches ist. Apple wird das MacBook vermutlich auch sehr schnell nächstes Jahr mit Kaby Lake CPUs aktualisieren. 