FROM node:22-alpine

WORKDIR /usr/src/csgofloat

COPY package*.json ./
RUN npm install --production

COPY . .

EXPOSE 8080
VOLUME /config

CMD [ "/bin/sh", "docker_start.sh" ]
