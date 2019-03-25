---
title:       TYPO3 Canonical-Url
description: Eine echte Canonical Url in TYPO3 die sich nicht durch AdWords Parameter und Ähnlichem austricksen lässt und keine Sicherheitslücken öffnet.
categories:
    - TYPO3
    - Software-Entwicklung
date:        2018-06-28 19:43:00 +0200
lastmod:     2019-03-25 12:24:00 +0100
---

update vom 18.7.2018: Ich hab eine winzige [canonical url extension] gebaut die nichts weiter tut als die canonical url korrekt zu generieren. 

## Falsche Lösungen

Um zu verstehen, was das Problem ist zeig ich erst einmal, wie man es **nicht** macht.

### Weg 1 (der Einfache)

Intuitiv würde man über TypoScript einfach die aktuelle Seite referenzieren. Das sähe so aus:

```
page.headerData.20 = TEXT
page.headerData.20 {
    wrap = <link rel="canonical" href="|">
    typolink.parameter.data = page:uid
    typolink.returnLast = url
}
```

Elegant und kurz und funktioniert auch solang man keine Erweiterungen benutzt, da dieser Weg keine Get-Parameter übernimmt.

### Weg 2 (der Fleißige)

Bei diesem Weg macht man sich die Mühe und definiert jeden Parameter, der im Canonical vorkommen kann, einzeln.

```
page.headerData.20 = TEXT
page.headerData.20 {
    wrap = <link rel="canonical" href="|">
    typolink.parameter.data = page:uid
    typolink.returnLast = url
    typolink.forceAbsoluteUrl = 1
    
    typolink.useCacheHash = 1
}

[globalVar = GP:tx_news_pi1|news > 0]
page.headerData.20.typolink.additionalParams = &tx_news_pi1[news]={GP:tx_news_pi1|news}
page.headerData.20.typolink.additionalParams.insertData = 1
[end]
```

Auch dieser Weg funktioniert, aber wird schwer sobald man auch noch Kombinationen an Parametern beachten muss. Außerdem ist er einfach nervig.

### Weg 3 (der Furchtbare)

Ich kenne das ja, man hält sich für Klug und sucht eine allgemeine Lösung. Diese sieht dann meistens so aus:

```
page.headerData.20 = TEXT
page.headerData.20 {
    wrap = <link rel="canonical" href="|">
    typolink.parameter.data = page:uid
    typolink.returnLast = url
    typolink.forceAbsoluteUrl = 1
    
    # bitte nicht so machen !
    typolink.addQueryString = 1
    typolink.addQueryString.method = GET
    typolink.addQueryString.exclude = id, cHash, tx_indexedsearch[sword], ...
    typolink.useCacheHash = 1
}
```

Das löst das Problem und alle Parameter werden übernommen. Es gibt sogar die Möglichkeit einzelne Parameter auszuschließen.
Super, oder? Was ist also das Problem? Nun, es ist sogar grob [dokumentiert](https://docs.typo3.org/typo3cms/TyposcriptReference/latest/Functions/Typolink/#addquerystring).

- Ich kann die Seite nun mit zB. AdWords Parametern wie `?gclid=somedata` aufrufen und der Canonical übernimmt diese.
- Da die Seite (hoffentlich) gecached wird, bestimmt der erste Besucher der Webseite was für Parameter im Canonical sind. Dies ist potenziell sogar ein Sicherheitsrisiko wenn die Seite gleichzeitig für XSS anfällig ist.
- Durch `useCacheHash` ist effektiv auch noch der [cHash Mechanismus] aus gekurbelt. Das heißt: wenn uns Jemand was Böses will, kann er Gigabyte an Cache erzeugen und auch noch gigantische Mengen an doppelten Inhalten bei Google einreichen.

Wenn du diesen Weg also nutzt solltest du den Canonical lieber gleich weg lassen. Der einzige Grund den Link so zu bauen ist um SEO tools aus zu tricksen.

## Wie also richtig?

Nach etwas Überlegung hab ich fest gestellt das TYPO3 einem das Problem unabsichtlich bereits löst.

Der [cHash Mechanismus] von TYPO3 verhindert eine Flut an unsinnigen Parametern im Cache in dem er durch eine Checksumme verifiziert das die Parameter tatsächlich von der TYPO3 Instanz generiert wurden. Er ist daher ideal für unseren Zweck da es von außen nicht möglich sein sollte Parameter hinzuzufügen. Es gibt in TypoScript allerdings keinen vorgesehenen Weg an die Werte heranzukommen, also müssen wir uns einen schaffen.

```php?start_inline=true
namespace Extension\Hook;

class CanonicalParametersGetDataHook implements ContentObjectGetDataHookInterface
{
    public function getDataExtension($getDataString, array $fields, $sectionValue, $returnValue, ContentObjectRenderer &$parentObject)
    {
        if ($getDataString !== 'canonical_parameters') {
            return $returnValue;
        }

        // das chash_array enthält alle Parameter aus denen die Checksumme generiert wird.
        // Vorsicht: Auch der encryptionKey ist darin enthalten und muss unbedingt entfernt werden.
        $cHash_array = $GLOBALS['TSFE']->cHash_array;
        unset($cHash_array['encryptionKey']);
        return GeneralUtility::implodeArrayForUrl('', $cHash_array);
    }
}
```
```php?start_inline=true
// ext_localconf.php
$GLOBALS['TYPO3_CONF_VARS']['SC_OPTIONS']['tslib/class.tslib_content.php']['getData'][$_EXTKEY] =
    \Extension\Hook\CanonicalParametersGetDataHook::class;
```

Nun haben wir uns eine schöne [getText] Funktion gebaut. Diese können wir so verwenden:

```
page.headerData.20 = TEXT
page.headerData.20 {
    wrap = <link rel="canonical" href="|">
    typolink.parameter.data = page:uid
    typolink.returnLast = url
    typolink.forceAbsoluteUrl = 1
    
    typolink.additionalParams.data = canonical_parameters
    typolink.useCacheHash = 1
}
```

Und tada, alle Get-Parameter die für das generieren der aktuellen Seite verantwortlich waren sind in der url wieder vorhanden.

Parameter können außerdem auf 2 Wege ausgeschlossen werden.

1. [FE][cHashExcludedParameters] entfernt den parameter nun sowohl aus der canonical als auch aus der cache relevance und ist daher ideal für zB. AdWords, Suchparameter ...
2. In dem Hook selbst kann man einfach weitere Parameter entfernen. Dadurch sind diese immer noch für den Cache relevant. Die ist sinnvoll für zB. eine zurück url 

Einen wirklichen Nachteil dieser Methode hab ich noch nicht gefunden, außer das man natürlich etwas PHP braucht. ~~Vielleicht bau ich auch nochmal eine Extension die nichts weiter tut als ein canonical tag und die getText Funktion bereit zu stellen.~~ Ich habe nun eine [canonical url extension] gebaut die den weg oben nochmal sauber implementiert.

Falls du noch etwas mehr wissen willst empfehle ich dir die Klasse/Methode `\TYPO3\CMS\Frontend\Page\CacheHashCalculator::getRelevantParameters` einmal zu überfliegen. Diese ist für die Liste in cHash_array verantwortlich.


[canonical url extension]: https://packagist.org/packages/nemo64/canonical-url
[cHash Mechanismus]: https://www.typo3lexikon.de/typo3-tutorials/core/cache/chash-was-ist-das.html
[getText]: https://docs.typo3.org/typo3cms/TyposcriptReference/8.7/DataTypes/Gettext/
