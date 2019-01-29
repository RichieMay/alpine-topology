FROM registry.locman.cn/sefon-public/alpine-storm:1.1.2 
MAINTAINER RichieMay <meibo@sefon.com>

USER root

ADD root /
RUN chmod +x ${SERVICE_HOME}/bin/* \
  && chown -R ${SERVICE_USER}:${SERVICE_GROUP} ${SERVICE_HOME}

USER $SERVICE_USER
WORKDIR $SERVICE_HOME

ENTRYPOINT ["bin/entrypoint.sh"]