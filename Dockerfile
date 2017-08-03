FROM ruby:2.1.10

WORKDIR /app

COPY Gemfile /app
COPY Gemfile.lock /app
RUN bundler install

CMD bundle exec jekyll serve --host 0.0.0.0