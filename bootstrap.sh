#!/usr/bin/env bash
apt-get update
apt-get install -y python-dev
apt-get install -y python-devel
apt-get install -y python-pip
apt-get install -y libxml-simple-perl
apt-get install -y libjson-perl

sudo pip install Flask

mkdir /vagrant/uploads
mkdir /vagrant/processed
