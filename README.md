# Prepare docker image with icinga2 and icingaweb2 installed


To build docker image run command: 
"docker build -t ziku/docker-icinga2:v1.0 ." (at the end there is dot that include Dockerfile in the command end)

Command for running docker image: 
"docker run -it -p 82:80 ziku/docker-icinga2:v1.0 /bin/bash" (with port 82 forwarding to local environment)

"docker run -itd -p 82:80 ziku/docker-icinga2:v1.0 /bin/bash" (run in the backgroud with port 82 forwarding to local environment)

Now it is possible to browse from local environment: http://localhost:82/icinga/ (icingaadmin:icingaadmin)


    
