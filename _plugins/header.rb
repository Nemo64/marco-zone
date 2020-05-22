# https://stackoverflow.com/a/53893197/1973256

class Jekyll::MarkdownHeader < Jekyll::Converters::Markdown
    def convert(content)
        super.gsub(/<h([23]) id="(.*?)">(.*)<\/h/, '<h\1 id="\2">\3&nbsp;<a href="#\2" class="permalink" title="permalink"></a></h')
    end
end
