FROM mysql/mysql-server:8.0

# Fix the locale error
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY provision.js /usr/provision.js

# Give the DBs a bit more time to fully stabilize before the shell hits them
ENTRYPOINT ["/bin/bash", "-c", "sleep 35 && mysqlsh --file /usr/provision.js"]