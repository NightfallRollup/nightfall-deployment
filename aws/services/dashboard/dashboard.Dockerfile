FROM node:16.17

EXPOSE 8080

WORKDIR /app
RUN apt-get update -y
COPY package*.json *.mjs options.js ./
COPY abis ./abis
COPY routes ./routes
COPY services ./services

RUN apt-get install -y curl

RUN npm ci

CMD ["npm", "start"]
