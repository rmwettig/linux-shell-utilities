#!/bin/bash

java -Xmx400g -jar "$1" preprocess "$2"
java -Xmx400g -jar "$1" import "$2"
java -Xmx400g -jar "$1" server "$2"
