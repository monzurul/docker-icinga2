# This dockerfile install and configure icinga2 and icingaweb2
# Icinga2 installation source code: https://github.com/monzurul/icinga2

FROM ubuntu:16.04

MAINTAINER Monzurul Hoque

RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt update \
	&& apt upgrade -y \
	&& apt install -y --no-install-recommends \
		software-properties-common \
		nginx \ 
		mariadb-client mariadb-server \
		php7.0-mysql php7.0-ldap \
		wget \
		unzip \
		sudo \
		curl \
	&& apt clean \
	&& rm -rf /var/lib/apt/lists/*

RUN /etc/init.d/mysql start

RUN export DEBIAN_FRONTEND=noninteractive \
	&& add-apt-repository ppa:formorer/icinga \
        && export DEBIAN_FRONTEND=noninteractive \
	&& apt update \
	&& apt install -y --no-install-recommends \
		icinga2	\
		icinga2-ido-mysql \
		icingacli \
		icingaweb2 \
		icingaweb2-module-monitoring \
		nagios-plugins \
	&& apt clean \
	&& rm -rf /var/lib/apt/lists/*

RUN sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.0/fpm/php.ini \
    	&& sed -i "s/;date.timezone =.*/date.timezone = UTC/" /etc/php/7.0/cli/php.ini \
    	&& addgroup --system icingaweb2 \
	&& usermod -aG icingaweb2 www-data \
	&& usermod -aG nagios www-data 

ADD content/ /tmp/

RUN ["/bin/bash", "/tmp/icinga2-setup.sh"]

EXPOSE 80 443 5665

ENTRYPOINT service rc.local start && bash

