# build circom from source for local verify
FROM  nightfall-circom:latest as builder
FROM  nightfall-rapidsnark:latest as rapidsnark

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y \
    && apt-get install -y netcat curl \
    && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs gcc g++ make \
    && apt install -y build-essential \
    && apt-get install -y libgmp-dev \
    && apt-get install -y libsodium-dev \
    && apt-get install -y nasm \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:pistache+team/unstable \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y libpistache-dev \
    && apt-get install -y nlohmann-json3-dev 

EXPOSE 80

ENV CIRCOM_HOME /app

WORKDIR /
COPY common-files common-files
WORKDIR /common-files
RUN npm ci
RUN npm link

WORKDIR /app
COPY config/default.js config/default.js
COPY /nightfall-deployer/circuits circuits
COPY --from=builder /app/circom/target/release/circom /app/circom
RUN mkdir -p /app/prover
COPY --from=rapidsnark /app/rapidsnark/build/proverServer /app/prover/proverServer
COPY ./worker/package.json ./worker/package-lock.json ./
COPY ./worker/src ./src
COPY ./worker/start-script ./start-script
COPY ./worker/start-dev ./start-dev

RUN npm ci

COPY common-files/classes node_modules/@polygon-nightfall/common-files/classes
COPY common-files/utils node_modules/@polygon-nightfall/common-files/utils
COPY common-files/constants node_modules/@polygon-nightfall/common-files/constants
COPY common-files/dll node_modules/@polygon-nightfall/common-files/dll

CMD ["npm", "start"]
