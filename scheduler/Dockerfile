FROM ruby:4.0-slim

RUN apt-get update && apt-get install -y build-essential git && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile ./
RUN bundle install

COPY . .

CMD ["ruby", "scheduler.rb"]
