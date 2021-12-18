FROM nginx:1.19.6-alpine

RUN apk add --no-cache \
		bash \
		openssl

# Add the main user with specific UID
ARG USER=nginx
ARG UID=1000
RUN sed -i -e "s/^\($USER:[^:]\):[0-9]*:[0-9]*:/\1:$UID:$UID:/" /etc/passwd && \
	sed -i -e "s/^\($USER:[^:]\):[0-9]*:/\1:$UID:/" /etc/group
