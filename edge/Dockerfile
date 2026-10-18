# Edge gateway: Apache with OpenID Connect sign-in (Keycloak) and the OWASP
# Core Rule Set. Ubuntu packages are used because mod_auth_openidc and the
# CRS are maintained there and receive security updates.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      apache2 libapache2-mod-auth-openidc libapache2-mod-security2 modsecurity-crs ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && a2enmod proxy proxy_http proxy_wstunnel headers macro auth_openidc security2 \
 && a2dissite 000-default \
 && cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf

COPY conf/lab.conf /etc/apache2/sites-available/lab.conf
COPY www/ /var/www/lab/
RUN a2ensite lab

EXPOSE 80
CMD ["apachectl", "-D", "FOREGROUND"]
