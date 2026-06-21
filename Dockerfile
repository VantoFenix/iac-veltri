
FROM nginx:alpine

RUN sed -i 's/80/8000/g' /etc/nginx/conf.d/default.conf

#Crear usuario no privilegiado
RUN addgroup -S appgroup && adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /var/cache/nginx /var/log/nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid


USER appuser

EXPOSE 8000

CMD ["nginx", "-g", "daemon off;"]