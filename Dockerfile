FROM ubuntu:16.04

ENV    SERVICE_USER=myuser \
    SERVICE_UID=10001 \
    SERVICE_GROUP=mygroup \
    SERVICE_GID=10001

RUN addgroup --gid ${SERVICE_GID} ${SERVICE_GROUP} && adduser --ingroup ${SERVICE_GROUP} --shell /sbin/nologin --uid ${SERVICE_UID} ${SERVICE_USER}

WORKDIR /
COPY ./user /user

RUN	chmod +x /user && \
	chown -R ${SERVICE_USER}:${SERVICE_GROUP} /user && \
	setcap 'cap_net_bind_service=+ep' /user

ENV HATEAOS user
ENV USER_DATABASE mongodb
ENV MONGO_DATABASE default
#ENV MONGO_URI mongodb://user-db-user:user-db4SockShop@user-db-shard-00-00-vvczq.mongodb.net:27017,user-db-shard-00-01-vvczq.mongodb.net:27017,user-db-shard-00-02-vvczq.mongodb.net:27017/test?ssl=true&replicaSet=user-db-shard-0&authSource=admin
ENV MONGO_URI mongodb://user-db:27017
ENV APP_PORT 8080

USER ${SERVICE_USER}

ARG BUILD_DATE
ARG BUILD_VERSION
ARG COMMIT

LABEL org.label-schema.vendor="Dynatrace" \
  org.label-schema.build-date="${BUILD_DATE}" \
  org.label-schema.version="${BUILD_VERSION}" \
  org.label-schema.name="Socksshop: User" \
  org.label-schema.description="REST API for User service" \
  org.label-schema.url="https://github.com/dynatrace-sockshop/user" \
  org.label-schema.vcs-url="github.com:dynatrace-sockshop/user.git" \
  org.label-schema.vcs-ref="${COMMIT}" \
  org.label-schema.schema-version="1.0"

CMD ["/user", "-port=8080"]
EXPOSE 8080