FROM gradle:7.1.1-jdk16

ENV GRADLE_VERSION=7.1.1

LABEL author="Gustavo Santos" \
      maintainer="Gustavo Santos" \
      org.label-schema.name="gustavofreze/gradle:${GRADLE_VERSION}" \
      org.label-schema.usage="https://github.com/gustavofreze/docker-images/blob/main/gradle/README.md" \
      org.label-schema.vcs-url="https://github.com/gustavofreze/docker-images/blob/main/gradle/${GRADLE_VERSION}/Dockerfile" \
      org.label-schema.schema-version="1.0"

RUN apt-get update  \
    && apt-get install --yes --no-install-recommends zip bash unzip \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 80
