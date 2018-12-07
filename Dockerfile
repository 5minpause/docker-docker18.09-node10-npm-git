# Get base alpine image with node 10
# Based on this: https://hub.docker.com/r/mhart/alpine-node/
# FROM alpine:3.6
FROM docker:18.09-git

MAINTAINER Holger Frohloff <holger@holgerfrohloff.de>>
ENV VERSION=v10.14.0 NPM_VERSION=6

# Install docker inside the image
# Copied from https://github.com/docker-library/docker/tree/91bbc4f7b06c06020d811dafb2266bcd7cf6c06d/18.09
# RUN apk add --no-cache \
# 		ca-certificates
#
# # set up nsswitch.conf for Go's "netgo" implementation (which Docker explicitly uses)
# # - https://github.com/docker/docker-ce/blob/v17.09.0-ce/components/engine/hack/make.sh#L149
# # - https://github.com/golang/go/blob/go1.9.1/src/net/conf.go#L194-L275
# # - docker run --rm debian:stretch grep '^hosts:' /etc/nsswitch.conf
# RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf
#
# ENV DOCKER_CHANNEL stable
# ENV DOCKER_VERSION 18.09.0
# # TODO ENV DOCKER_SHA256
# # https://github.com/docker/docker-ce/blob/5b073ee2cf564edee5adca05eee574142f7627bb/components/packaging/static/hash_files !!
# # (no SHA file artifacts on download.docker.com yet as of 2017-06-07 though)
#
# RUN set -eux; \
# 	\
# # this "case" statement is generated via "update.sh"
# 	apkArch="$(apk --print-arch)"; \
# 	case "$apkArch" in \
# 		x86_64) dockerArch='x86_64' ;; \
# 		armhf) dockerArch='armel' ;; \
# 		aarch64) dockerArch='aarch64' ;; \
# 		ppc64le) dockerArch='ppc64le' ;; \
# 		s390x) dockerArch='s390x' ;; \
# 		*) echo >&2 "error: unsupported architecture ($apkArch)"; exit 1 ;;\
# 	esac; \
# 	\
# 	if ! wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
# 		echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
# 		exit 1; \
# 	fi; \
# 	\
# 	tar --extract \
# 		--file docker.tgz \
# 		--strip-components 1 \
# 		--directory /usr/local/bin/ \
# 	; \
# 	rm docker.tgz; \
# 	\
# 	dockerd --version; \
# 	docker --version
#
# COPY modprobe.sh /usr/local/bin/modprobe
# COPY docker-entrypoint.sh /usr/local/bin/
#
# RUN chmod 777 /usr/local/bin/docker-entrypoint.sh \
#     && ln -s /usr/local/bin/docker-entrypoint.sh /
#
# ENTRYPOINT ["docker-entrypoint.sh"]
# CMD ["sh"]


RUN apk add --no-cache curl make gcc g++ python linux-headers binutils-gold gnupg libstdc++ && \
  for server in hkps://hkps.pool.sks-keyservers.net pgp.mit.edu keyserver.pgp.com; do \
    gpg --keyserver $server --recv-keys \
      94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
      B9AE9905FFD7803F25714661B63B535A4C206CA9 \
      77984A986EBC2AA786BC0F66B01FBB92821C587A \
      71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
      FD3A5288F042B6850C66B31F09FE44734EB7990E \
      8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
      C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
      DD8F2338BAE7501E3DD5AC78C273792F7D83545D && break; \
  done && \
  curl -sfSLO https://nodejs.org/dist/${VERSION}/node-${VERSION}.tar.xz && \
  curl -sfSL https://nodejs.org/dist/${VERSION}/SHASUMS256.txt.asc | gpg --batch --decrypt | \
    grep " node-${VERSION}.tar.xz\$" | sha256sum -c | grep ': OK$' && \
  tar -xf node-${VERSION}.tar.xz && \
  cd node-${VERSION} && \
  ./configure --prefix=/usr ${CONFIG_FLAGS} && \
  make -j$(getconf _NPROCESSORS_ONLN) && \
  make install
RUN cd / && \
  if [ -z "$CONFIG_FLAGS" ]; then \
    if [ -n "$NPM_VERSION" ]; then \
      npm install -g npm@${NPM_VERSION}; \
    fi; \
    find /usr/lib/node_modules/npm -name test -o -name .bin -type d | xargs rm -rf; \
    if [ -n "$YARN_VERSION" ]; then \
      for server in ipv4.pool.sks-keyservers.net keyserver.pgp.com ha.pool.sks-keyservers.net; do \
        gpg --keyserver $server --recv-keys \
          6A010C5166006599AA17F08146C2130DFD2497F5 && break; \
      done && \
      curl -sfSL -O https://yarnpkg.com/${YARN_VERSION}.tar.gz -O https://yarnpkg.com/${YARN_VERSION}.tar.gz.asc && \
      gpg --batch --verify ${YARN_VERSION}.tar.gz.asc ${YARN_VERSION}.tar.gz && \
      mkdir /usr/local/share/yarn && \
      tar -xf ${YARN_VERSION}.tar.gz -C /usr/local/share/yarn --strip 1 && \
      ln -s /usr/local/share/yarn/bin/yarn /usr/local/bin/ && \
      ln -s /usr/local/share/yarn/bin/yarnpkg /usr/local/bin/ && \
      rm ${YARN_VERSION}.tar.gz*; \
    fi; \
  fi && \
  apk del curl make gcc g++ python linux-headers binutils-gold gnupg ${DEL_PKGS} && \
  rm -rf ${RM_DIRS} /node-${VERSION}* /usr/share/man /tmp/* /var/cache/apk/* \
    /root/.npm /root/.node-gyp /root/.gnupg /usr/lib/node_modules/npm/man \
/usr/lib/node_modules/npm/doc /usr/lib/node_modules/npm/html /usr/lib/node_modules/npm/scripts


RUN apk add --update \
    bash \
    && rm -rf /var/cache/apk/*
# RUN npm install -g npm@6;
CMD ["bash"]
