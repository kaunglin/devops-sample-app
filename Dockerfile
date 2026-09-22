FROM nginx:1.27-alpine

# Jenkins passes the short git SHA so the running page shows which build it is.
ARG BUILD_VERSION=dev

COPY index.html /usr/share/nginx/html/index.html
RUN sed -i "s/__BUILD_VERSION__/${BUILD_VERSION}/" /usr/share/nginx/html/index.html

EXPOSE 80
