FROM ubuntu:22.04

RUN apt-get update -y
RUN apt-get install -y netcat curl
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get install -y nodejs gcc g++ make

EXPOSE 80 8080

ENTRYPOINT ["/app/docker-entrypoint.sh"]

WORKDIR /
COPY common-files common-files
COPY config/default.js app/config/default.js

WORKDIR /common-files
RUN npm ci
RUN npm link

WORKDIR /app
COPY test/adversary/lazy-optimist/src src
COPY nightfall-optimist/docker-entrypoint.sh nightfall-optimist/package*.json ./

RUN npm ci

COPY common-files/classes node_modules/@polygon-nightfall/common-files/classes
COPY common-files/utils node_modules/@polygon-nightfall/common-files/utils
COPY common-files/constants node_modules/@polygon-nightfall/common-files/constants
COPY common-files/dll node_modules/@polygon-nightfall/common-files/dll

CMD ["npm", "start"]
