FROM ruby:2.5

WORKDIR /app

COPY Gemfile* /app/
RUN bundle install

ENTRYPOINT ["bundle", "exec", "jekyll"]
CMD ["serve", "--host=0.0.0.0", "--unpublished", "--future", "--drafts"]