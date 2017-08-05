---
title:      TYPO3 Formular Finisher zum Editor hinzufügen
description: >
    Der umständliche und undokumentierte Weg ein Finisher in den Typo3 8.7 Formular-Editor zu bekommen.   
categories: 
    - Software-Entwicklung
    - Typo3
    - PHP
date:       2017-08-05 22:00:00 +0200
---

Es gibt viele Gründe weshalb man einen weiteren Finisher brauchen würde. Mein Grund war eine [Cleverreach] integration. Leider ist die TYPO3 Api etwas unnötig kompliziert gestalltet.  Ein einfaches `ValidatorInterface` kombiniert mit einer ext_localconf.php methode `FormUtility::addValidator` war wohl zu einfach.

Das Ergebnis im TYPO3-Backend soll dann am Ende ungefähr so aussehen:

{% responsive_image path: 'assets/cleverreach-typo3-form.png' alt: 'Ansicht vom TYPO3 Backend' %}

## Die Finisher Klasse

Als erstes würde ich den Finisher anlegen. Wenn man sich die mitgelieferten Finisher als Beispiel nimmt, gehören unsere in `Classes\Model\Finishers`. Wenn du ein relativ gutes Beispiel suchst, wie ein funktionierender Finisher aussieht, würde ich mich an den `EmailFinisher` und den `RedirectFinisher` halten.

```php?start_inline=true
namespace Vendor\VendorExtension\Domain\Finishers;

use TYPO3\CMS\Form\Domain\Finishers\AbstractFinisher;

class CleverreachSubscribeFinisher extends AbstractFinisher
{
    /**
     * Dies sind die Optionen die wir später haben wollen.
     * 
     * @var array
     */
    protected $defaultOptions = [
        'apiKey' => ''
    ];

    /**
     * Hier kommt unsere schöne Logik hin.
     */
    protected function executeInternal()
    {
        // liefert alle formular werte
        $this->finisherContext->getFormValues();
        // holt die Option apikey, die wir später definieren
        $this->parseOption('apiKey');
        
        // die exakte implementierung zeige ich hier nicht
        // die wird ehh je nach anforderung unterschiedlich sein 
    }
}
```

Das wirkt nun recht simple aber nun kommt der lustige Teil.

## Form Framework Konfiguration

Wir brauchen 3 Yaml Dateien um den Finisher zu registrieren. Die Form Extension packt diese in `Configuration/Yaml`. Ich persöhnlich würde den Ordner allerdings `Form` nennen um ein wenig klarheit zu schaffen für was die Configuration ist.

Ich dump die Yaml Datein einfach mal hier rein, den es ist nicht kompliziert, es ist einfach nur massiv.

```yaml
# BaseSetup.yaml
TYPO3:
  CMS:
    Form:
      prototypes:
        standard:
          finishersDefinition:
            CleverreachSubscribe:
              implementationClassName: 'Vendor\VendorExtension\Domain\Finishers\CleverreachSubscribeFinisher'
```

```yaml
# FormEditor.yaml
TYPO3:
  CMS:
    Form:
      prototypes:
        standard:
          formElementsDefinition:
            Form:
              formEditor:
                editors:
                  900:
                    # Diese Definition erweitert das Dropdown der Finisher im menü
                    selectOptions:
                      35:
                        value: 'CleverreachSubscribe'
                        label: 'Cleverreach Subscribe'
                propertyCollections:
                  finishers:
                    # Hier wird definiert, welche Felder der Finisher später haben soll
                    25:
                      identifier: 'CleverreachSubscribe'
                      editors:
                        __inheritances:
                          10: 'TYPO3.CMS.Form.mixins.formElementMixins.BaseCollectionEditorsMixin'
                        100:
                          label: "Cleverreach Subscribe"
                        110:
                          identifier: 'apiKey'
                          templateName: 'Inspector-TextEditor'
                          label: 'apiKey'
                          propertyPath: 'options.apiKey'
                          propertyValidators:
                            10: 'NotEmpty'
                        120:
                          identifier: 'listId'
                          templateName: 'Inspector-TextEditor'
                          label: 'listId'
                          propertyPath: 'options.listId'
                          enableFormelementSelectionButton: true
                          propertyValidators:
                            10: 'NotEmpty'
                            20: 'FormElementIdentifierWithinCurlyBracesInclusive'
                        130:
                          identifier: 'formId'
                          templateName: 'Inspector-TextEditor'
                          label: 'formId'
                          propertyPath: 'options.formId'
                          enableFormelementSelectionButton: true
                          propertyValidators:
                            10: 'NotEmpty'
                            20: 'FormElementIdentifierWithinCurlyBracesInclusive'
                        140:
                          identifier: 'email'
                          templateName: 'Inspector-TextEditor'
                          label: 'Subscribers email'
                          propertyPath: 'options.email'
                          enableFormelementSelectionButton: true
                          propertyValidators:
                            10: 'NotEmpty'
                            20: 'FormElementIdentifierWithinCurlyBracesInclusive'
                        150:
                          identifier: 'source'
                          templateName: 'Inspector-TextEditor'
                          label: 'Source (Cleverreaches examples use a Projekt Name here)'
                          propertyPath: 'options.source'
                          propertyValidators:
                            10: 'NotEmpty'
                            
          # hier ist definiert welche optionen das javascript im backend beim hinzufügen lädt
          # am besten sollten es die selben sein wie in finisher 
          finishersDefinition:
            CleverreachSubscribe:
              formEditor:
                iconIdentifier: 't3-form-icon-finisher'
                label: 'A Label that seems to be never used...'
                predefinedDefaults:
                  options:
                    apiKey: ''
                    listId: ''
                    formId: ''
                    email: ''
                    source: 'Typo3 Website'
```

```yaml
# FormEngineSetup.yaml
TYPO3:
  CMS:
    Form:
      prototypes:
        standard:
          finishersDefinition:
            CleverreachSubscribe:
              FormEngine:
                label: "When is this label used? And for what?"
                elements:
                  # hier nochmal alle Felder
                  # ich habe keine Ahnung wofür diese sind aber ohne geht es nicht
                  # spontan würde ich behaupten das es tca configuration ist
                  # aber ich definiere keine Datenbank Felder ~ vielleicht ist das aber eine Option
                  apiKey: {label: apiKey, config: {type: input}}
                  listId: {label: listId, config: {type: input}}
                  formId: {label: formId, config: {type: input}}
                  email:  {label: email , config: {type: input}}
                  source: {label: source, config: {type: input}}
```

Und das war so ziemlich der nervigste Teil. Jetzt müssen wir nur noch unsere yaml Dateien registrieren. Dafür brauchen wir wieder gutes altes TypoScript.

```
# frontend configuration
plugin.tx_form.settings.yamlConfigurations {
    1499086547 = EXT:extension/Configuration/Form/BaseSetup.yml
    1499088215 = EXT:extension/Configuration/Form/FormEngineSetup.yml
}
# backend configuration
module.tx_form.settings.yamlConfigurations {
    1499086547 = EXT:extension/Configuration/Form/BaseSetup.yml
    1499086867 = EXT:extension/Configuration/Form/FormEditorSetup.yml
    1499088215 = EXT:extension/Configuration/Form/FormEngineSetup.yml
}
```

## Zusammenfassung

Im Endeffekt ist es nicht sehr kompliziert wenn man weiß was man tun muss. Das nervigste ist, dass alles mehrfach definiert werden muss. Das hinzufügen einer Option muss an 4 Stellen über 3 Dateien eingetragen werden. Auch die pfade zu den Werten lassen sich nicht sonderlich gut merken. Ich vermute einfach, das nie daran gedacht wurde das jemand diese Api nutzt. Das würde auch das Fehlen der Dokumentation erklären ~ bei TYPO3 ist man sich da nie sicher.

[Cleverreach]: https://www.cleverreach.com/
