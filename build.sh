#!/bin/bash

# Version-independent agent names used by Dockerfiles 
MACHINE_AGENT=MachineAgent.zip
APP_SERVER_AGENT=JavaAgent.zip
PHP_AGENT=PHPAgent.tar.bz2
WEBSERVER_AGENT=webserver_agent.tar.gz
CPP_AGENT=appdynamics-sdk-native.tar.gz
TOMCAT=apache-tomcat.tar.gz
ADRUM=adrum.js

cleanUp(){
  # Delete agent distros from docker build dirs
  (cd Java-App && rm -f ${APP_SERVER_AGENT} ${MACHINE_AGENT} ${TOMCAT})
  (cd PHP-App && rm -f ${PHP_AGENT} ${MACHINE_AGENT})
  (cd Node-App && rm -f ${MACHINE_AGENT})
  (cd Python-App && rm -f ${MACHINE_AGENT})
  (cd WebServer && rm -f ${MACHINE_AGENT} ${WEBSERVER_AGENT})
  (cd Cpp-App && rm -f ${CPP_AGENT} ${MACHINE_AGENT})
  (cd Angular-App/mixapp-angular/client/js && rm -f ${ADRUM})

  # Remove dangling images left-over from build
  if [[ `docker images -q --filter "dangling=true"` ]]
  then
    echo
    echo "Deleting intermediate containers..."
    docker images -q --filter "dangling=true" | xargs docker rmi;
  fi
}
trap cleanUp EXIT

promptForAgents(){
  read -e -p "Enter path to App Server Agent (AppServerAgent-<ver>.zip): " APP_SERVER_AGENT_PATH
  read -e -p "Enter path to Machine Agent (64bit-linux-<ver>.zip): " MACHINE_AGENT_PATH
  read -e -p "Enter path to PHP Agent (x64-linux-<ver>.tar.bz): " PHP_AGENT_PATH
  read -e -p "Enter path to WebServer Agent (nativeWebServer-64bit-linux-<ver>.tar.gz): " WEBSERVER_AGENT_PATH
  read -e -p "Enter path of Tomcat (.tar.gz): " TOMCAT_PATH
  read -e -p "Enter path of C++ Native SDK (nativeSDK-64bit-linux-<ver>.tar.gz): " CPP_AGENT_PATH
  read -e -p "Enter path of EUM Agent - Adrum (adrum-<ver>.js): " ADRUM_PATH
}

copyAgents(){
  echo "Adding AppDynamics Agents: 
  App Server Agent: ${APP_SERVER_AGENT_PATH} 
  Machine Agent:  ${MACHINE_AGENT_PATH}
  Tomcat: ${TOMCAT_PATH} 
  Php Agent  ${PHP_AGENT_PATH}
  Web Server Agent: ${WEBSERVER_AGENT_PATH}
  C++ Agent: ${CPP_AGENT_PATH}
  Adrum: ${ADRUM_PATH}"
    
  echo "Adding Machine Agent to build"
  cp ${MACHINE_AGENT_PATH} Java-App/${MACHINE_AGENT}
  cp ${MACHINE_AGENT_PATH} PHP-App/${MACHINE_AGENT}
  cp ${MACHINE_AGENT_PATH} Node-App/${MACHINE_AGENT}
  cp ${MACHINE_AGENT_PATH} Python-App/${MACHINE_AGENT}
  cp ${MACHINE_AGENT_PATH} WebServer/${MACHINE_AGENT}
  cp ${MACHINE_AGENT_PATH} Cpp-App/${MACHINE_AGENT}

  echo "Adding App Server Agent to build"
  cp ${APP_SERVER_AGENT_PATH} Java-App/${APP_SERVER_AGENT}

  echo "Adding PHP Agent to build"
  cp ${PHP_AGENT_PATH} PHP-App/${PHP_AGENT}

  echo "Adding WebServer Agent to build"
  cp ${WEBSERVER_AGENT_PATH} WebServer/${WEBSERVER_AGENT}

  echo "Adding tomcat path to build" 
  cp ${TOMCAT_PATH} Java-App/${TOMCAT} 

  echo "Adding C++ Native SDK path to build" 
  cp ${CPP_AGENT_PATH} Cpp-App/${CPP_AGENT} 

  echo "Adding adrum.js to Angular App" 
  cp ${ADRUM_PATH} Angular-App/mixapp-angular/client/js/${ADRUM} 
}

# Usage information
if [[ $1 == *--help* ]]
then
  echo "Specify agent locations: build.sh
          -a <Path to App Server Agent>
          -c <Path to C++ Agent>
          -m <Path to Machine Agent>
          -p <Path to Php Agent>
          -t <Path to Tomcat>
          -w <Path to Web Server Agent>
          -r <Path to Adrum Agent>"
  echo "Prompt for agent locations: build.sh"
  exit 0
fi

if  [ $# -eq 0 ]
then
  promptForAgents
else
  # Allow user to specify locations of Agent installers
  while getopts "a:c:m:p:t:w:r:" opt; do
    case $opt in
      a)
        APP_SERVER_AGENT_PATH=$OPTARG
        if [ ! -e ${APP_SERVER_AGENT_PATH} ]; then
          echo "Not found: ${APP_SERVER_AGENT_PATH}"; exit 1
        fi
        ;;
      c)
        CPP_AGENT_PATH=$OPTARG
        if [ ! -e ${CPP_AGENT_PATH} ]; then
          echo "Not found: ${CPP_AGENT_PATH}"; exit 1
        fi
        ;; 
      m)
        MACHINE_AGENT_PATH=$OPTARG
        if [ ! -e ${MACHINE_AGENT_PATH} ]; then
          echo "Not found: ${MACHINE_AGENT_PATH}"; exit 1
        fi
        ;;
      p)
        PHP_AGENT_PATH=$OPTARG 
	      if [ ! -e ${PHP_AGENT_PATH} ]; then
          echo "Not found: ${PHP_AGENT_PATH}"; exit 1        
        fi
        ;;
      t)
        TOMCAT_PATH=$OPTARG 
	      if [ ! -e ${TOMCAT_PATH} ]; then
          echo "Not found: ${TOMCAT_PATH}"; exit 1        
        fi
        ;;
      w)
        WEBSERVER_AGENT_PATH=$OPTARG
        if [ ! -e ${WEBSERVER_AGENT_PATH} ]; then
          echo "Not found: ${WEBSERVER_AGENT_PATH}"; exit 1
        fi
        ;;
      r)
        ADRUM_PATH=$OPTARG
        if [ ! -e ${ADRUM_PATH} ]; then
          echo "Not found: ${ADRUM_PATH}"; exit 1
        fi
        ;;
      \?)
        echo "Invalid option: -$OPTARG"
        ;;
    esac
  done
fi

copyAgents

echo; echo "Building MixApp containers"

echo; echo "Building Python App..."
(cd Python-App && docker build -t appdynamics/mixapp-python .) || exit $?

echo; echo "Building PHP App..."
(cd PHP-App && docker build -t appdynamics/mixapp-php .) || exit $?

echo; echo "Building Node App..."
(cd Node-App && docker build -t appdynamics/mixapp-nodejs .) || exit $?

echo; echo "Building the Java App..."
(cd Java-App && docker build -t appdynamics/mixapp-java .) || exit $?

echo; echo "Building the C++ Container..."
(cd Cpp-App && docker build -t appdynamics/mixapp-cpp .) || exit $?

echo; echo "Building the WebServer..."
(cd WebServer && docker build -t appdynamics/mixapp-webserver .) || exit $?

echo; echo "Building the Load Gen Container..."
(cd Load-Gen && docker build -t appdynamics/mixapp-load .) || exit $?

echo; echo "Building the Angular.js Container..."
(cd Angular-App && docker build -t appdynamics/mixapp-angular .) || exit $?


HOSTNAME=`hostname`

sed -i.bk "s/ HOST_NAME/ ${HOSTNAME}/" docker-compose.yml

rm -f docker-compose.yml.bk
