---
title:       TYPO3 Css/Js-Spam verhindern
description: TYPO3 kombiniert normalerweise alle css/js Dateien zu einer Datei. Dies hat jedoch einen großen Hacken. 
categories:
    - TYPO3
    - Software-Entwicklung
date:        2018-04-25 16:00:00 +0100
lastmod:     2018-07-30 15:00:00 +0200
---

## Das Problem

Im Normalfall ist alles einfach. Man inkludiert alle Ressourcen via TypoScript in 'page.includeCss' und 'page.includeJsFooter'. TYPO3 generiert jeweils eine CSS und JS Datei und alle sind glücklich.

Dann gibt es aber noch Erweiterungen. Viele davon fügen gerne mal CSS und JavaScript über den 'PageRenderer' via 'addCssFile' und 'addJsFooterFile' hinzu (ganz böse Erweiterungen fügen auch mal JS im head hinzu).
Das Problem: Der Parameter 'excludeFromConcatenation' ist Standardmäßig 'false'.
Das heißt das auf der Seite, auf der das Plugin vorhanden ist, TYPO3 ein komplett neues Css/Js Bundle erstellen muss. Jedes Bundle enthält dann alle bisherigen Ressourcen die der Nutzer eigentlich bereits hat.

## Workaround

Da ich nicht jede Erweiterung (es sind viele ~ ich zeig aber mal keine Finger) anpassen will hab ich einen schnellen fix implementiert: Ich hab den 'PageRenderer' überschrieben und einfach den 'excludeFromConcatenation' Parameter geändert. Das sieht dann so aus:

```php?start_inline=true
namespace Vendor\Extension\Override;

/**
 * Default $excludeFromConcatenation = true
 */
class PageRenderer extends \TYPO3\CMS\Core\Page\PageRenderer
{
    public function addJsLibrary(
        $name,
        $file,
        $type = 'text/javascript',
        $compress = false,
        $forceOnTop = false,
        $allWrap = '',
        $excludeFromConcatenation = true,
        $splitChar = '|',
        $async = false,
        $integrity = '')
    {
        parent::addJsLibrary($name, $file, $type, $compress, $forceOnTop, $allWrap, $excludeFromConcatenation, $splitChar, $async, $integrity);
    }

    public function addJsFooterLibrary(
        $name,
        $file,
        $type = 'text/javascript',
        $compress = false,
        $forceOnTop = false,
        $allWrap = '',
        $excludeFromConcatenation = true,
        $splitChar = '|',
        $async = false,
        $integrity = '')
    {
        parent::addJsFooterLibrary($name, $file, $type, $compress, $forceOnTop, $allWrap, $excludeFromConcatenation, $splitChar, $async, $integrity);
    }

    public function addJsFile(
        $file,
        $type = 'text/javascript',
        $compress = true,
        $forceOnTop = false,
        $allWrap = '',
        $excludeFromConcatenation = true,
        $splitChar = '|',
        $async = false,
        $integrity = '')
    {
        parent::addJsFile($file, $type, $compress, $forceOnTop, $allWrap, $excludeFromConcatenation, $splitChar, $async, $integrity);
    }

    public function addJsFooterFile
        $file,
        $type = 'text/javascript',
        $compress = true,
        $forceOnTop = false,
        $allWrap = '',
        $excludeFromConcatenation = true,
        $splitChar = '|',
        $async = false,
        $integrity = '')
    {
        parent::addJsFooterFile($file, $type, $compress, $forceOnTop, $allWrap, $excludeFromConcatenation, $splitChar, $async, $integrity);
    }

    public function addCssFile
        $file,
        $rel = 'stylesheet',
        $media = 'all',
        $title = '',
        $compress = true,
        $forceOnTop = false,
        $allWrap = '',
        $excludeFromConcatenation = true,
        $splitChar = '|')
    {
        parent::addCssFile($file, $rel, $media, $title, $compress, $forceOnTop, $allWrap, $excludeFromConcatenation, $splitChar);
    }

    public function addCssLibrary
        $file,
        $rel = 'stylesheet',
        $media = 'all',
        $title = '',
        $compress = true,
        $forceOnTop = false,
        $allWrap = '',
        $excludeFromConcatenation = true,
        $splitChar = '|')
    {
        parent::addCssLibrary($file, $rel, $media, $title, $compress, $forceOnTop, $allWrap, $excludeFromConcatenation, $splitChar);
 }
}
```

Und in der `ext_localconf.php` dann einfach:

```php?start_inline=true
$GLOBALS['TYPO3_CONF_VARS']['SYS']['Objects'][\TYPO3\CMS\Core\Page\PageRenderer::class]['className'] = \Vendor\Extension\Override\PageRenderer::class;
```

Das ist immer noch nicht so geil, da man schließlich eigentlich nur eine Datei am Ende haben will, aber es ist um Welten besser als das Standardverhalten. 