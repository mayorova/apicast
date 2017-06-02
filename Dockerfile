FROM quay.io/3scale/apicast:master

# Copy customized source code to the appropriate directories
COPY ./examples/cors/apicast_cors.lua /opt/app-root/src/src/
COPY ./examples/cors/cors.conf /opt/app-root/src/apicast.d/
