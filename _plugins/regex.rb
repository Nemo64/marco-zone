module Jekyll
  module Regex
    def regex_replace(str, pattern, replacement)
      return str.gsub(/#{pattern}/, replacement)
    end
    def regex_scan(str, pattern)
      return str.scan(/#{pattern}/)
    end
  end
end

Liquid::Template.register_filter(Jekyll::Regex)