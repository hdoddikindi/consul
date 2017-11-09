FROM alpine:3.2

ENV CONSUL_VERSION 0.7.0
ENV CONSUL_HTTP_PORT  8500
ENV CONSUL_HTTPS_PORT 8543
ENV CONSUL_DNS_PORT   53

COPY consul_0.7.0_linux_amd64.zip /tmp/consul_0.7.0_linux_amd64.zip
COPY consul_0.7.0_web_ui.zip /tmp/consul_0.7.0_web_ui.zip

RUN apk --update add openssl zip curl ca-certificates jq \
&& cat /etc/ssl/certs/*.pem > /etc/ssl/certs/ca-certificates.crt \
&& sed -i -r '/^#.+/d' /etc/ssl/certs/ca-certificates.crt \
&& rm -rf /var/cache/apk/* \
&& mkdir -p /etc/consul /etc/consul/ssl /var/consul/ui /data \
&& unzip /tmp/consul_${CONSUL_VERSION}_linux_amd64.zip -d /usr/bin \
&& rm -f /tmp/consul_${CONSUL_VERSION}_linux_amd64.zip \
&& unzip /tmp/consul_${CONSUL_VERSION}_web_ui.zip -d /var/consul/ui \
&& rm -f /tmp/consul_${CONSUL_VERSION}_web_ui.zip

COPY config.json /etc/consul/config.json

EXPOSE ${CONSUL_HTTP_PORT}
EXPOSE ${CONSUL_HTTPS_PORT}
EXPOSE ${CONSUL_DNS_PORT}

COPY run.sh /usr/bin/run.sh
RUN chmod +x /usr/bin/run.sh

COPY run1.sh /usr/bin/run1.sh
RUN chmod +x /usr/bin/run1.sh

ENTRYPOINT ["/usr/bin/run.sh"]
CMD []
