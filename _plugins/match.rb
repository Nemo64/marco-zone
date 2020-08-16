module Jekyll
  module RegexReplace
    def regex_scan(str, pattern)
      return str.scan(/#{pattern}/)
    end
  end
end

Liquid::Template.register_filter(Jekyll::RegexReplace)