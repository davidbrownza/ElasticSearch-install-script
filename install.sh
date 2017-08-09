#!/bin/bash

# install script for installing elasticsearch on Ubuntu. Should be run with root privileges.


function default_options() {
    PACKAGE=elasticsearch
    
    VERSION=5.4.2
    CONFIG_DIR=/etc/elasticsearch
    DATA_DIR=/var/lib/elasticsearch
    
    HOST=127.0.0.1
    PORT=9200
}


function program_options() {
    
    default_options
    
    while [ $# -gt 0 ] 
    do
        key="$1"
        case $key in
            --version)
                VERSION=${2:-$VERSION}
                shift # past argument=value
                ;;
            --host)
                HOST=${2:-$HOST}
                shift # past argument=value
                ;;
            --port)
                PORT=${2:-$PORT}
                shift # past argument=value
                ;;
            --config-dir)
                CONFIG_DIR=${2:-$CONFIG_DIR}
                shift # past argument=value
                ;;
            --data-dir)
                DATA_DIR=${2:-$DATA_DIR}
                shift # past argument=value
                ;;
            --help)
                usage
                exit
                ;;
            *)
                # unknown option
                echo "Unknown option: $1"
                usage
                exit
            ;;
        esac
        shift 
    done
    
    echo "Installing '$PACKAGE' using the following options:"
    echo "VERSION: $VERSION"
    echo "HOST: $HOST"
    echo "PORT: $PORT"
    echo "CONFIG_DIR: $CONFIG_DIR"
    echo "DATA_DIR: $DATA_DIR"
    echo "###########"
}


function get_package_status() {
    dpkg-query -W --showformat='${Status}\n' $PACKAGE | grep "install ok installed"
}


function get_package_version() {
    dpkg-query -W --showformat='${VERSION}\n' $PACKAGE
}


function remove_package() {
    echo "Uninstalling $PACKAGE..."
    dpkg -r $PACKAGE
}


function install_package() {
    # clear old .deb file
    if [ -f $PACKAGE_NAME ]; then
        echo "Clearing old .deb package."
        rm $PACKAGE_NAME
    fi
    
    echo "Installing $PACKAGE_NAME"
    
    # download elasticsearch .deb file
    wget https://artifacts.elastic.co/downloads/elasticsearch/$PACKAGE_NAME
  
    # install elasticsearch
    dpkg -i $PACKAGE_NAME
}


function configure_service() {
    echo "Configuring service to launch at start up."
    update-rc.d $PACKAGE defaults
    
    cp elasticsearch.template.yml elasticsearch.yml
    
    echo "Setting data directory: $DATA_DIR"
    sed -i -e 's|#path.data: %DATA_DIR%|path.data: '"$DATA_DIR"'|g' elasticsearch.yml
    
    echo "Setting binding address: $HOST"
    sed -i -e 's/#network.host: %HOST%/network.host: '"$HOST"'/g' elasticsearch.yml
    
    echo "Setting port: $PORT"
    sed -i -e 's/#http.port: %PORT%/http.port: '"$PORT"'/g' elasticsearch.yml
    
    echo "Moving new config file to $CONFIG_DIR"
    mv elasticsearch.yml $CONFIG_DIR/elasticsearch.yml
    
    if [ get_service_status = 'INACTIVE' ]; then
        service $PACKAGE start
    else
        service $PACKAGE restart
    fi
}


function get_service_status() {
    if [ ps -ef | grep -v grep | grep elastic+ | wc -l > 0 ]; then
        echo "ACTIVE"
    else
        echo "INACTIVE"
    fi
}


function clean_up() {
    rm elasticsearch-*.deb
}

function usage() {
    echo "Usage: install.sh --config-dir <path> --data-dir <path> --host <host IP> --port <port> --version <version>"
    echo "Options:"
    echo "--config-dir: the directory that the elsaticsearch.yml config file is located in"
    echo "--data-dir: the directory that elsaticsearch will store the data in"
    echo "--host: the IP address that elasticsearch should be served on"
    echo "--port: the port that elasticsearch should be served on"
    echo "--version: the version of elasticsearch that should be downloaded and installed"
}


function main() {
    program_options $@
    
    PACKAGE_NAME=${PACKAGE}-${VERSION}.deb
    
    STATUS=`get_package_status`
    
    if [ "install ok installed" == "$STATUS" ]; then
        CURRENT_VERSION=`get_package_version`
        
        if [ "$VERSION" == "$CURRENT_VERSION" ]; then
            echo "Version '$CURRENT_VERSION' of '$PACKAGE' is already installed."
            
            configure_service
        else
            echo "Version '$CURRENT_VERSION' of '$PACKAGE' is installed, but we are looking for version '$VERSION'."
            
            remove_package && install_package && configure_service
        fi
        
    else
        echo "Package '$PACKAGE' is not installed."
        install_package && configure_service
    fi
    
    clean_up
}

main $@
