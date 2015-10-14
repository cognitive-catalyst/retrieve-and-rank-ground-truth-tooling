#!/usr/bin/env bash

# Vincent Dowling
# Watson Ecosystem
#
# usage: ./install.sh
# description: Configures all necessary dependencies to work with migrateGt.sh and migrateContent.sh


# Exits if java is not found
has_java ()  {
    if [ ! -x "$(which java)" ]; then
        echo "java is either not installed or not properly configured. Please set this up before proceeding..."
        echo "Exiting..."
        exit 0
    fi
}


# Exits if python is not set up
has_python () {
    if [ ! -x "$(which python)" ]; then
        echo "python is either not installed or not properly configured. Please set this up before proceeding..."
        echo "Exiting..."
        exit 0
    fi
}


# Configure python installer
configure_python_installer () {
    if [ ! -x "$(which pip)" ]; then
        if [ ! -x "$(which easy_install)" ]; then
            # Can't find pip or easy_install, so fail
            echo "easy_install is not set up. Please install a new version of python that includes 'setuptools'"
            echo "Exiting with status code 1"
            exit 0
        else
            echo "Installing python-pip as sudo. Please enter your password whem prompted..."
            sudo easy_install pip -q pip
            if [ ! -x "$(which pip)" ]; then
                PYTHON_INSTALLER_PATH=$(which easy_install)
                PYTHON_INSTALLER_NAME="easy_install"
                echo "python-pip was not successfully installed. Using easy_install=@$PYTHON_INSTALLER_PATH to install python dependencies..."
            else
                PYTHON_INSTALLER_PATH=$(which pip)
                PYTHON_INSTALLER_NAME="pip"
                echo "python-pip was successfully installed. Using pip=@$PYTHON_INSTALLER_PATH to install python dependencies..."
            fi
        fi
    else
        PYTHON_INSTALLER_PATH=$(which pip)
        PYTHON_INSTALLER_NAME="pip"
        echo "python-pip=@$PYTHON_INSTALLER_PATH was found and already installed. Using pip to install dependencies..."
    fi
}


# Install lxml
build_lxml_from_source () {
    LXML_LIB=$1
    directory_exists "$LXML_LIB"
    pushd $LXML_LIB
        python setup.py build --static-deps --libxml2-version=2.8.0  --libxslt-version=1.1.24
        python setup.py install
    popd
}

# Install dependencies
install_python_dependencies () {
    if [ "$PYTHON_INSTALLER_NAME" = "pip" ]; then
        $PYTHON_INSTALLER_PATH install -U $@
    else
        $PYTHON_INSTALLER_PATH -U $@
    fi
}


# Exit if the file does not exist
file_exists () {
    local FILE=$1
    if [ ! -e "$FILE" ]; then
        echo "file=$FILE does not exist. The path of this file must be properly configured to proceed"
        echo "Exiting..."
        exit 0
    fi
}


# Exit if the directory does not exist
directory_exists () {
    local DIR_NAME=$1
    if [ ! -d "$DIR_NAME" ]; then
        echo "directory=$DIR_NAME does not exist. The path of this directory must be properly configured to proceed"
        echo "Exiting..."
        exit 0
    fi
}


# Fail if Java/python are not installed/configured
#has_java
has_python
PYTHON_DIRECTORY=bin/python
LIB_DIRECTORY=lib
HAS_MODULE_SCRIPT=$PYTHON_DIRECTORY/has_module.py
directory_exists $PYTHON_DIRECTORY
directory_exists $LIB_DIRECTORY
file_exists $HAS_MODULE_SCRIPT


# Configure the python installer and attempt to install dependencies
configure_python_installer
install_python_dependencies requests argparse lxml
HAS_REQUESTS="$(python $HAS_MODULE_SCRIPT requests)"
HAS_LXML="$(python $HAS_MODULE_SCRIPT lxml)"
if [ "$HAS_LXML" != "FOUND" ]; then
    build_lxml_from_source $LIB_DIRECTORY
fi
HAS_LXML="$(python $HAS_MODULE_SCRIPT lxml)"
HAS_ARGPARSE="$(python $HAS_MODULE_SCRIPT argparse)"
if [[ "$HAS_REQUESTS" = "FOUND" ]] && [[ "$HAS_LXML" = "FOUND" ]] && [[ "$HAS_ARGPARSE" = "FOUND" ]]; then
    echo "All dependencies have been properly installed!"
    echo "Exiting..."
    exit 0
else
    echo "All dependencies have not been properly installed..."
    if [[ "$HAS_REQUESTS" != "FOUND" ]]; then
        echo "python dependency 'requests' has not been properly installed..."
    fi
    if [[ "$HAS_LXML" != "FOUND" ]]; then
        echo "python dependency 'lxml' has not been properly installed..."
    fi
    if [[ "$HAS_ARGPARSE" != "FOUND" ]]; then
        echo "python dependency 'argparse' has not been properly installed..."
    fi
fi


# Can't find xcode-select, so exit
if [ ! -x "$(which xcode-select)" ]; then
    echo "xcode-select was not found. If you are on a Mac, please set up xcode to proceed"
    echo "Exiting..."
    exit 0
fi


# User decides to install with xcode-select or exit
INSTALL_WITH_XCODE=$(python -c "print raw_input('To proceed, this script will install necessary command-line dependencies. This process can take a long time. Would you like to procced? (Enter y to continue) ').strip()")
if [ "$INSTALL_WITH_XCODE" = "y" ]; then
    echo "Updating command-line utilities..."
    sudo xcode-select --install
    echo "Reinstalling dependencies requests, argparse, lxml..."
    install_python_dependencies requests argparse lxml
    HAS_REQUESTS="$(python $HAS_MODULE_SCRIPT requests)"
    HAS_LXML="$(python $HAS_MODULE_SCRIPT lxml)"
    HAS_ARGPARSE="$(python $HAS_MODULE_SCRIPT argparse)"
    if [[ "$HAS_REQUESTS" = "FOUND" ]] && [[ "$HAS_LXML" = "FOUND" ]] && [[ "$HAS_ARGPARSE" = "FOUND" ]]; then
        echo "All dependencies have been properly installed!"
        echo "Exiting..."
        exit 0
    else
        echo "All dependencies have not been properly installed..."
        if [[ "$HAS_REQUESTS" != "FOUND" ]]; then
            echo "python dependency 'requests' has not been properly re-installed..."
        fi
        if [[ "$HAS_LXML" != "FOUND" ]]; then
            echo "python dependency 'lxml' has not been properly re-installed..."
        fi
        if [[ "$HAS_ARGPARSE" != "FOUND" ]]; then
            echo "python dependency 'argparse' has not been properly re-installed..."
        fi
        echo "installation failed!"
    fi
fi
echo "Exiting..."
exit 0
