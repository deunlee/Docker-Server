# https://hub.docker.com/_/node

FROM node:17.3-alpine3.12

RUN apk add --no-cache \
		bash

# Add the main user with specific UID
ARG USER=nodejs
ARG UID=1000
RUN sed -i -e "s/^\($USER:[^:]\):[0-9]*:[0-9]*:/\1:$UID:$UID:/" /etc/passwd && \
	sed -i -e "s/^\($USER:[^:]\):[0-9]*:/\1:$UID:/" /etc/group
