FROM ruby:2.4

WORKDIR /app

COPY Gemfile /app
COPY Gemfile.lock /app
RUN bundle install

CMD bundle exec jekyll serve --host 0.0.0.0 --unpublished --future --drafts