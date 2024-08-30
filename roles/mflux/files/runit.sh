#! /bin/bash

/usr/bin/java -jar /opt/mediaflux/bin/aserver.jar application.home=/opt/mediaflux nogui

while true; do
    sleep 60
done