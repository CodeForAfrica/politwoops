FROM ruby:2.2

RUN apt-get update --fix-missing

# application dependencies
RUN apt-get install -y libmysqlclient-dev libpq-dev libcurl4-openssl-dev nodejs
RUN apt-get install -y wget python-setuptools python-dev
RUN echo "gem: --no-ri --no-rdoc" > ~/.gemrc

WORKDIR /web/
ADD Gemfile /web/
ADD Gemfile.lock /web/
ADD ./vendor/cache /web/vendor/cache

RUN bundle install --deployment --without development --jobs=2

ADD . /web/

ENV RAILS_ENV production

ENV PHANTOMJS_VERSION 2.1.1

# Commands
RUN \
  apt-get install -y vim git wget libfreetype6 libfontconfig bzip2 && \
  mkdir -p /srv/var
RUN wget -q --no-check-certificate -O /tmp/phantomjs-2.1.1-linux-x86_64.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2
RUN tar -xjf /tmp/phantomjs-2.1.1-linux-x86_64.tar.bz2 -C /tmp
RUN rm -f /tmp/phantomjs-2.1.1-linux-x86_64.tar.bz2
RUN mv /tmp/phantomjs-2.1.1-linux-x86_64/ /srv/var/phantomjs
RUN ln -s /srv/var/phantomjs/bin/phantomjs /usr/local/bin/phantomjs
RUN git clone https://github.com/casperjs/casperjs.git /srv/var/casperjs
RUN ln -s /srv/var/casperjs/bin/casperjs /usr/local/bin/casperjs

RUN apt-get install -y beanstalkd

RUN git clone --depth 1 https://github.com/chegejames/politwoops-tweet-collector.git && \
    mkdir -p /web/tmp/tweet-images && \
    easy_install pip && \
    pip install -r politwoops-tweet-collector/requirements.txt
ADD config/tweets-client.ini /web/politwoops-tweet-collector/conf/tweets-client.ini

RUN mkdir -p /web/data/heartbeats
RUN mkdir -p /web/tmp/tweet-images
RUN ["chmod", "+x", "bin/run-collector-dockercmd"]
RUN ["chmod", "+x", "/web/bin/run-tweets-client"]
RUN ["chmod", "+x", "/web/bin/run-politwoops-worker"]
RUN ["chmod", "+x", "/web/bin/run-screenshot-worker"]

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

VOLUME ["/data"]
CMD bin/run-collector-dockercmd

RUN bundle exec rake assets:clobber assets:precompile assets:gzip assets:sync


EXPOSE 80
CMD bundle exec unicorn -c ./config/unicorn.conf.rb
