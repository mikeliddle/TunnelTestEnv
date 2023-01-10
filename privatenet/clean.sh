DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/vars

docker container stop $RESOURCE_NAME $PROXY_NAME $BIND_NAME
docker container rm $RESOURCE_NAME $PROXY_NAME $BIND_NAME
docker image rm -f $PROXY_DOCKER_TAG

if [ -d $WD ]; then
    rm -rf $WD
fi
