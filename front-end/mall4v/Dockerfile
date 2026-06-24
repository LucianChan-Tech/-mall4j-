FROM nginx:1.20
RUN rm -f /etc/nginx/conf.d/default.conf
COPY ./dist /usr/share/nginx/html/dist
COPY ./nginx.conf /etc/nginx/conf.d/default.conf