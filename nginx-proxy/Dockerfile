FROM nginxproxy/nginx-proxy

RUN apt-get update
RUN apt-get install -y geoip-database
RUN apt-get clean all

RUN sed -i '1 i\load_module "modules/ngx_http_geoip_module.so";\n' /etc/nginx/nginx.conf