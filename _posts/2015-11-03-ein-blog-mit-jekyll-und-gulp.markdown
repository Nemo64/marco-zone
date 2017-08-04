---
title:       Ein Blog mit Jekyll und Gulp
description: Beste Webentwicklungsumgebung die ich je auf die Beine gestellt hab, doch war das Einrichten (mit meinen Ansprüchen) nicht so einfach wie ich dachte.
image:       jekyll.jpeg
date:        2015-11-03 20:00:00 +0100
lastmod:     2015-11-08 20:00:00 +0100
categories:
    - Software-Entwicklung
    - Gulp
    - Jekyll
redirects:
    - path: /posts/ein-blog-mit-jekyll-und-gulp
    - path: /post/ein-blog-mit-jekyll-und-gulp
---

## Der ursprüngliche Plan
Eigentlich wollte ich nur einen Server aufsetzen um kleinere Witz-Seiten wie [is it friday yet] zu erstellen, da ich so kleine php Seite ziemlich gerne mal zusammen hacke wenn mir die Idee dafür kommt. Da ich bereits eine nicht genutzte VM bei [DigitalOcean] hatte, dachte ich mir das ich diese einfach mal auf vordermann bringe. Ich hätte zwar auch einen Shared-Hoster nehmen können aber wo wäre da der Spaß gewesen. ;)

Da ich nginx lange nicht mehr verwendet hab, hab ich diesen mal schnell installiert. Bevor ich aber php-fpm installiert hab, kam mir der gedanke mal zu forschen, welche Möglichkeiten man hat statische Seiten zu generieren. Dabei stieß ich schnell über [StaticGen] auf [Jekyll]. Das Build-System ist mir schon mal unter die Augen gekommen, da es von GitHub Pages verwendet wird, daher war ich nun interessiert.

## Erste Einrichtung

Die erste Einrichtung ist eigentlich ein Kinderspiel und ist direkt auf der Startseite von [Jekyll] beschrieben, auch die ersten Seiten zu bauen war ziemlich leicht. Mit `jekyll new` wird ein Beispiel-Projekt generiert an dem man sich recht gut entlang hangeln kann.

Eigentlich kopiert Jekyll einfach nur  alles was in dem Projekt-Order ist in den Build-Order, jedoch mit ein paar wichtigen Ausnahmen. Es gibt ein [paar Ordner](http://jekyllrb.com/docs/structure/) welche von Jekyll besonders behandelt werden. Außerdem kann man jede Datei mit einem sogenannten "[Front Matter]" ausstatten, welches eine kleine Yaml Datei am anfang der Datei ist. Das Konzept ist recht einfach und [gut dokumentiert](https://jekyllrb.com/docs/home/). Die Probleme entstehen erst, wenn man Abhängigkeiten mit bower einbringt und diese am besten dann auch noch komprimieren will.

## Assets mit Gulp und Bower

Ich bin nicht neu in der Web-Entwicklung und habe nunmal etwas hohe Ansprüche. Jekyll bringt einen sass und CoffeeScript Kompiler mit sich. Mir war jedoch sofort klar dass das nicht ausreichen wird wenn ich bootstrap und 1000 weitere libraries verwenden will. Außerdem will ich natürlich dass das css/js komprimiert wird, also musste ein fortgeschrittenes Build-Tool her.

Nun die Entscheidung für Gulp war für mich ganz klar. Ich kenne es bereits und hab gute Erfahrungen damit. Um Gulp verwenden zu können waren allerdings erst mal einige Anpassungen an der `_config.yml` von Jekyll nötig.

{% highlight yaml %}
exclude:
  - bower_components
  - bower.json
  - node_modules
  - package.json
  - gulpfile.js

keep_files:
  - assets
{% endhighlight %}

`exclude` sorgt dafür, dass bestimmte Dateien nicht von Jekyll mit in den Build-Ordner kopiert werden, damit nicht alle rohen Dateien und die Build-Konfiguration sich nachher im DocumentRoot befinden. `keep_files` verhindert, dass Die erwähnten Dateien aus dem Build Ordner gelöscht werden, in dem Beispiel werde ich also alle Dateien in den `assets` Ordner werfen.

Nun kann in dem Projekt, wie bei jedem anderen bower Projekt, mit `bower install --save bootstrap#^4.0` [Bootstrap] installiert werden. Danach noch den Schwall gulp Abhängigkeiten mit `npm install --save-dev gulp gulp-sass` und schon geht es weiter mit dem `gulpfile.js` im Root-Ordner. Ich werde nicht erklären wie Gulp funktioniert aber Grundlegend ist nun folgendes möglich:

{% highlight javascript %}
gulp.task('sass', function () {
    var sass = require('gulp-sass');
    gulp.src('bower_components/bootstrap/scss/bootstrap.scss')
        .pipe(sass({outputStyle: 'compressed'}).on('error', sass.logError))
        .pipe(gulp.dest('web/assets'))
});
gulp.task('default', ['sass']);
{% endhighlight %}

Und nun können wir einfach die styles im layout einbinden einbinden.

{% highlight html %}
<link rel="stylesheet" href="{{ "{{" }} '/assets/bootstrap.css' | prepend: site.baseurl }}">
{% endhighlight %}

Nach dem Prinzip ist alles möglich, was mit Gulp möglich ist. Ich würde für css noch `gulp-sourcemap` und `gulp-autoprefixer` empfehlen.

## Jekyll build mit Gulp ausführen

Dies ist noch ein netter bonus. Jekyll selbst kann über Gulp auf gerufen werden. Die Idee für den [Jekyll Build in Gulp] habe ich hier Gefunden.

{% highlight javascript %}
gulp.task('jekyll', function (gulpCallBack) {
    var spawn = require('child_process').spawn;
    var jekyll = spawn('jekyll', [
        'build',
        '--no-watch',
        '--destination', 'web'
    ], {stdio: 'inherit'});
    jekyll.on('exit', function (code) {
        gulpCallBack(code === 0 ? null : 'ERROR: Jekyll process exited with code: ' + code);
    });
});
{% endhighlight %}


Dadurch verliert man zwar `jekyll serve` aber das kann Gulp auch. Zum Ausliefern der Seite kann [BrowserSync] verwendet werden. Das Geile daran ist: BrowserSync kann auch automatisch geänderte Dateien ausliefern und mehrere Browsers gleichzeitig beliefern um das Ergebnis auf möglichst vielen Plattformen gleichzeitig zu betrachten. Hier jetzt eine Gulp-Konfiguration für sass und jekyll welches mit BrowserSync ausgeliefert wird:

{% highlight javascript %}
var browserSync = require('browser-sync').create();

var deployPath = 'web';
var sourceFiles = {
    scss: '_sources/*.scss'
};
var targetDirectories = {
    assets: deployPath + '/assets'
};

gulp.task('jekyll', function (gulpCallBack) {
    var spawn = require('child_process').spawn;
    var jekyll = spawn('jekyll', [
        'build', '--no-watch',
        '--destination', deployPath
    ], {stdio: 'inherit'});

    jekyll.on('exit', function (code) {
        gulpCallBack(code === 0 ? null : 'ERROR: Jekyll process exited with code: ' + code);
    });
});

gulp.task('html', ['jekyll'], function () {
    var htmlmin = require('gulp-htmlmin');
    var path = require('path');

    gulp.src([path.join(deployPath, '*.html'), path.join(deployPath, '**/*.html')])
        .pipe(htmlmin({ collapseWhitespace: true }))
        .pipe(gulp.dest(deployPath))
        .pipe(browserSync.stream());
});

gulp.task('sass', function () {
    var sass = require('gulp-sass');
    var autoprefixer = require('gulp-autoprefixer');
    var sourcemaps = require('gulp-sourcemaps');

    gulp.src(sourceFiles.scss)
        .pipe(sourcemaps.init())
        .pipe(sass({outputStyle: 'compressed'}).on('error', sass.logError))
        .pipe(autoprefixer({ browsers: ['> 1% in DE, last 2 versions, Firefox ESR'] }))
        .pipe(sourcemaps.write('.'))
        .pipe(gulp.dest(targetDirectories.assets))
        .pipe(browserSync.stream())
});

gulp.task('css', ['sass']);

gulp.task('default', ['clean', 'html', 'css']);

gulp.task('watch', ['default'], function () {
    gulp.watch([
        '*.html',
        '_*/*.html',
        'pages/*.html',
        '*.markdown',
        '*/*.markdown',
        '*'
    ], ['html']);
    gulp.watch([
        '_sources/*.scss',
        '_sources/**/*.scss'
    ], ['css']);
});

gulp.task('serve', ['watch'], function () {
    browserSync.init({
        server: {
            baseDir: deployPath
        }
    });
});
{% endhighlight %}

## Schlußwort

Dieser Eintrag ist viel größer geworden als ich vorgesehen hab und eigentlich wollte ich noch viel mehr auf Jekyll layouts und Strukturierung ein gehen. Stattdessen ist es nur die Einrichtung der Umgebung geworden und selbst dort hab ich nur die Oberfläche beleuchten können.

Ich werde noch weiter meine Erfahrungen mit Jekyll sammeln und später bestimmt noch etwas dazu zu sagen haben.

[is it friday yet]: http://isitfridayyet.net/
[DigitalOcean]: https://www.digitalocean.com/?refcode=44bae78c77f9
[multiverse]: https://wiki.ubuntuusers.de/paketquellen#multiverse
[StaticGen]: https://www.staticgen.com/
[Jekyll]: https://jekyllrb.com/
[Liquid]: https://github.com/Shopify/liquid
[Front Matter]: http://jekyllrb.com/docs/frontmatter/
[Bootstrap]: http://getbootstrap.com/
[Jekyll Build in Gulp]: http://blog.webbb.be/use-jekyll-with-gulp/#the-html--jekyll-task
[BrowserSync]: http://www.browsersync.io/