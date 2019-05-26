FROM ubuntu:18.10
#!/usr/bin/env bash
RUN apt-get update
#RUN apt-get install -y python-dev python-devel python-pip 
RUN apt-get install -y python3-pip libxml-simple-perl libjson-perl
RUN apt-get install -y curl nano

RUN pip3 install Flask
WORKDIR /vagrant  
RUN mkdir -p uploads processed 
COPY . .

# rm -f /vagrant/uploads/*;rm -f /vagrant/processed/*;
ENV FLASK_APP=/vagrant/parserService.py
ENV FLASK_ENV=development
ENV PERL5LIB=/vagrant/parser:/vagrant/parser/parsers/pkgs
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# ENTRYPOINT [ "python3" ]
CMD cd /vagrant;./parserService.py