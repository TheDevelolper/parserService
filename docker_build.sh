set -x
set -e
docker stop cparser_service | true
docker rm cparser_service | true
docker build --tag parser_service:dev .
docker run --name cparser_service -d -p 5000:5000 -it parser_service:dev
sleep 1
docker logs -f cparser_service
