FROM node:16.17

# install node
RUN apt-get update
RUN apt-get install -y netcat

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

CMD ["npm", "start"]