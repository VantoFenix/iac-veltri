
FROM nginx:alpine

RUN sed -i 's/80/8000/g' /etc/nginx/conf.d/default.conf

EXPOSE 8000

CMD ["nginx", "-g", "daemon off;"]