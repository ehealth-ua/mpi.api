def author() {
  return sh(returnStdout: true, script: 'git log -n 1 --format="%an"').trim()
}
pipeline {
  agent {
    node { 
      label 'ehealth-build-big' 
      }
  }
  environment {
    PROJECT_NAME = 'mpi'
    MIX_ENV = 'test'
    DOCKER_NAMESPACE = 'edenlabllc'
    POSTGRES_VERSION = '10'
    POSTGRES_USER = 'postgres'
    POSTGRES_PASSWORD = 'postgres'
    POSTGRES_DB = 'postgres'
    NO_ECTO_SETUP = 'true'
  }
  stages {
    stage('Init') {
      options {
        timeout(activity: true, time: 3)
      }
      steps {
        sh 'cat /etc/hostname'
        sh 'sudo docker rm -f $(sudo docker ps -a -q) || true'
        sh 'sudo docker rmi $(sudo docker images -q) || true'
        sh 'sudo docker system prune -f'
        sh '''
          sudo docker run -d --name postgres -p 5432:5432 edenlabllc/alpine-postgre:pglogical-gis-1.1;
          sudo docker run -d --name kafkazookeeper -p 2181:2181 -p 9092:9092 edenlabllc/kafka-zookeeper:2.1.0;
          sudo docker ps;
        '''
        sh '''
          until psql -U postgres -h localhost -c "create database ehealth";
            do
              sleep 2
            done
          psql -U postgres -h localhost -c "create database mpi_dev";
          psql -U postgres -h localhost -c "create database deduplication_dev";          
        '''
        sh '''
          until sudo docker exec -i kafkazookeeper /opt/kafka_2.12-2.1.0/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic medical_events;
            do
              sleep 2
            done
          sudo docker exec -i kafkazookeeper /opt/kafka_2.12-2.1.0/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic person_events;
          sudo docker exec -i kafkazookeeper /opt/kafka_2.12-2.1.0/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic mongo_events;
        '''        
        sh '''
          mix local.hex --force;
          mix local.rebar --force;
          mix deps.get;
          mix deps.compile;
        '''
      }
    }
    stage('Test') {
      options {
        timeout(activity: true, time: 3)
      }
      steps {
        sh '''
          until sudo apt-get install -y python3-pip;
            do
              sleep 2
            done
          pip3 install setuptools wheel
          pip3 install -r python_requirements.txt        
          (curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/tests.sh -o tests.sh; chmod +x ./tests.sh; ./tests.sh) || exit 1;
          '''
      }
    }
    stage('Build') {
//      failFast true
      parallel {
        stage('Build manual-merger-app') {
          options {
            timeout(activity: true, time: 3)
          }
          environment {
            APPS='[{"app":"manual_merger","chart":"mpi","namespace":"mpi","deployment":"manual-merger", "label":"manual-merger"}]'
          }
          steps {
            sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/build-container.sh -o build-container.sh;
              chmod +x ./build-container.sh;
              ./build-container.sh;  
            '''
          }
        }
        stage('Build person-deactivator-app') {
          options {
            timeout(activity: true, time: 3)
          }
          environment {
            APPS='[{"app":"person_deactivator","chart":"mpi","namespace":"mpi","deployment":"person-deactivator", "label":"person-deactivator"}]'
          }
          steps {
            sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/build-container.sh -o build-container.sh;
              chmod +x ./build-container.sh;
              ./build-container.sh;  
            '''
          }
        }
        stage('Build mpi-app') {
          options {
            timeout(activity: true, time: 3)
          }
          environment {
            APPS='[{"app":"mpi","chart":"mpi","namespace":"mpi","deployment":"api","label":"api"}]'
          }
          steps {
            sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/build-container.sh -o build-container.sh;
              chmod +x ./build-container.sh;
              ./build-container.sh;  
            '''
          }
        }
        stage('Build mpi-scheduler-app') {
          options {
            timeout(activity: true, time: 3)
          }
          environment {
            APPS='[{"app":"mpi_scheduler","chart":"mpi","namespace":"mpi","deployment":"mpi-scheduler","label":"mpi-scheduler"}]'
          }
          steps {
            sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/build-container.sh -o build-container.sh;
              chmod +x ./build-container.sh;
              ./build-container.sh;  
            '''
          }
        }
        stage('Build person-updates-producer-app') {
          options {
            timeout(activity: true, time: 3)
          }
          environment {
            APPS='[{"app":"person_updates_producer","chart":"mpi","namespace":"mpi","job":"true"}]'
          }
          steps {
            sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/build-container.sh -o build-container.sh;
              chmod +x ./build-container.sh;
              ./build-container.sh;  
            '''
          }
        }
        stage('Build deduplication-app') {
          options {
            timeout(activity: true, time: 3)
          }
          environment {
            APPS='[{"app":"deduplication","chart":"mpi","namespace":"mpi","job":"true","dockerfile":"Dockerfile.deduplication"}]'
          }
          steps {
            sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/build-container.sh -o build-container.sh;
              chmod +x ./build-container.sh;
              ./build-container.sh;  
            '''
          }
        }
      }
    }    
    stage('Run manual-merger and push') {
      options {
        timeout(activity: true, time: 3)
      }
      environment {
        APPS='[{"app":"manual_merger","chart":"mpi","namespace":"mpi","deployment":"manual-merger", "label":"manual-merger"}]'
      }
      steps {
        sh '''
          curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/start-container.sh -o start-container.sh;
          chmod +x ./start-container.sh; 
          ./start-container.sh;
        '''
        withCredentials(bindings: [usernamePassword(credentialsId: '8232c368-d5f5-4062-b1e0-20ec13b0d47b', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
          sh 'echo " ---- step: Push docker image ---- ";'
          sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/push-changes.sh -o push-changes.sh;
              chmod +x ./push-changes.sh;
              ./push-changes.sh
            '''
        }
      }
    }
    stage('Run person-deactivator and push') {
      options {
        timeout(activity: true, time: 3)
      }
      environment {
        APPS='[{"app":"person_deactivator","chart":"mpi","namespace":"mpi","deployment":"person-deactivator", "label":"person-deactivator"}]'
      }
      steps {
        sh '''
          curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/start-container.sh -o start-container.sh;
          chmod +x ./start-container.sh; 
          ./start-container.sh;
        '''
        withCredentials(bindings: [usernamePassword(credentialsId: '8232c368-d5f5-4062-b1e0-20ec13b0d47b', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
          sh 'echo " ---- step: Push docker image ---- ";'
          sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/push-changes.sh -o push-changes.sh;
              chmod +x ./push-changes.sh;
              ./push-changes.sh
            '''
        }
      }
    }
    stage('Run mpi and push') {
      options {
        timeout(activity: true, time: 3)
      }
      environment {
        APPS='[{"app":"mpi","chart":"mpi","namespace":"mpi","deployment":"api","label":"api"}]'
      }
      steps {
        sh '''
          curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/start-container.sh -o start-container.sh;
          chmod +x ./start-container.sh; 
          ./start-container.sh;
        '''
        withCredentials(bindings: [usernamePassword(credentialsId: '8232c368-d5f5-4062-b1e0-20ec13b0d47b', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
          sh 'echo " ---- step: Push docker image ---- ";'
          sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/push-changes.sh -o push-changes.sh;
              chmod +x ./push-changes.sh;
              ./push-changes.sh
            '''
        }
      }
    }
    stage('Run mpi-scheduler and push') {
      options {
        timeout(activity: true, time: 3)
      }
      environment {
        APPS='[{"app":"mpi_scheduler","chart":"mpi","namespace":"mpi","deployment":"mpi-scheduler","label":"mpi-scheduler"}]'
      }
      steps {
        sh '''
          curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/start-container.sh -o start-container.sh;
          chmod +x ./start-container.sh; 
          ./start-container.sh;
        '''
        withCredentials(bindings: [usernamePassword(credentialsId: '8232c368-d5f5-4062-b1e0-20ec13b0d47b', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
          sh 'echo " ---- step: Push docker image ---- ";'
          sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/push-changes.sh -o push-changes.sh;
              chmod +x ./push-changes.sh;
              ./push-changes.sh
            '''
        }
      }
    }
    stage('Run person-updates-producer and push') {
      options {
        timeout(activity: true, time: 3)
      }
      environment {
        APPS='[{"app":"person_updates_producer","chart":"mpi","namespace":"mpi","job":"true"}]'
      }
      steps {
        sh '''
          curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/start-container.sh -o start-container.sh;
          chmod +x ./start-container.sh; 
          ./start-container.sh;
        '''
        withCredentials(bindings: [usernamePassword(credentialsId: '8232c368-d5f5-4062-b1e0-20ec13b0d47b', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
          sh 'echo " ---- step: Push docker image ---- ";'
          sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/push-changes.sh -o push-changes.sh;
              chmod +x ./push-changes.sh;
              ./push-changes.sh
            '''
        }
      }
    }
    stage('Run deduplication and push') {
      options {
        timeout(activity: true, time: 3)
      }
      environment {
        APPS='[{"app":"deduplication","chart":"mpi","namespace":"mpi","job":"true","dockerfile":"Dockerfile.deduplication"}]'
      }
      steps {
        sh '''
          curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/start-container.sh -o start-container.sh;
          chmod +x ./start-container.sh; 
          ./start-container.sh;
        '''
        withCredentials(bindings: [usernamePassword(credentialsId: '8232c368-d5f5-4062-b1e0-20ec13b0d47b', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
          sh 'echo " ---- step: Push docker image ---- ";'
          sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/push-changes.sh -o push-changes.sh;
              chmod +x ./push-changes.sh;
              ./push-changes.sh
            '''
        }
      }
    }
    stage('Deploy') {
      options {
        timeout(activity: true, time: 3)
      }
      environment {
        APPS='[{"app":"manual_merger","chart":"mpi","namespace":"mpi","deployment":"manual-merger", "label":"manual-merger"},{"app":"person_deactivator","chart":"mpi","namespace":"mpi","deployment":"person-deactivator", "label":"person-deactivator"},{"app":"mpi","chart":"mpi","namespace":"mpi","deployment":"api","label":"api"},{"app":"mpi_scheduler","chart":"mpi","namespace":"mpi","deployment":"mpi-scheduler","label":"mpi-scheduler"},{"app":"person_updates_producer","chart":"mpi","namespace":"mpi","job":"true"},{"app":"deduplication","chart":"mpi","namespace":"mpi","job":"true","dockerfile":"Dockerfile.deduplication"}]'
      }
      steps {
        withCredentials([string(credentialsId: '86a8df0b-edef-418f-844a-cd1fa2cf813d', variable: 'GITHUB_TOKEN')]) {
          withCredentials([file(credentialsId: '091bd05c-0219-4164-8a17-777f4caf7481', variable: 'GCLOUD_KEY')]) {
            sh '''
              curl -s https://raw.githubusercontent.com/edenlabllc/ci-utils/umbrella_jenkins_gce/autodeploy.sh -o autodeploy.sh;
              chmod +x ./autodeploy.sh;
              ./autodeploy.sh
            '''
          }
        }
      }
    }
  }
  post {
    success {
      script {
        if (env.CHANGE_ID == null) {
          slackSend (color: 'good', message: "Build <${env.RUN_DISPLAY_URL}|#${env.BUILD_NUMBER}> (<https://github.com/edenlabllc/ehealth.api/commit/${env.GIT_COMMIT}|${env.GIT_COMMIT.take(7)}>) of ${env.JOB_NAME} by ${author()} *success* in ${currentBuild.durationString.replace(' and counting', '')}")
        } else if (env.BRANCH_NAME.startsWith('PR')) {
          slackSend (color: 'good', message: "Build <${env.RUN_DISPLAY_URL}|#${env.BUILD_NUMBER}> (<https://github.com/edenlabllc/ehealth.api/pull/${env.CHANGE_ID}|${env.GIT_COMMIT.take(7)}>) of ${env.JOB_NAME} in PR #${env.CHANGE_ID} by ${author()} *success* in ${currentBuild.durationString.replace(' and counting', '')}")
        }
      }
    }
    failure {
      script {
        if (env.CHANGE_ID == null) {
          slackSend (color: 'danger', message: "Build <${env.RUN_DISPLAY_URL}|#${env.BUILD_NUMBER}> (<https://github.com/edenlabllc/ehealth.api/commit/${env.GIT_COMMIT}|${env.GIT_COMMIT.take(7)}>) of ${env.JOB_NAME} by ${author()} *failed* in ${currentBuild.durationString.replace(' and counting', '')}")
        } else if (env.BRANCH_NAME.startsWith('PR')) {
          slackSend (color: 'danger', message: "Build <${env.RUN_DISPLAY_URL}|#${env.BUILD_NUMBER}> (<https://github.com/edenlabllc/ehealth.api/pull/${env.CHANGE_ID}|${env.GIT_COMMIT.take(7)}>) of ${env.JOB_NAME} in PR #${env.CHANGE_ID} by ${author()} *failed* in ${currentBuild.durationString.replace(' and counting', '')}")
        }
      }
    }
    aborted {
      script {
        if (env.CHANGE_ID == null) {
          slackSend (color: 'warning', message: "Build <${env.RUN_DISPLAY_URL}|#${env.BUILD_NUMBER}> (<https://github.com/edenlabllc/ehealth.api/commit/${env.GIT_COMMIT}|${env.GIT_COMMIT.take(7)}>) of ${env.JOB_NAME} by ${author()} *canceled* in ${currentBuild.durationString.replace(' and counting', '')}")
        } else if (env.BRANCH_NAME.startsWith('PR')) {
          slackSend (color: 'warning', message: "Build <${env.RUN_DISPLAY_URL}|#${env.BUILD_NUMBER}> (<https://github.com/edenlabllc/ehealth.api/pull/${env.CHANGE_ID}|${env.GIT_COMMIT.take(7)}>) of ${env.JOB_NAME} in PR #${env.CHANGE_ID} by ${author()} *canceled* in ${currentBuild.durationString.replace(' and counting', '')}")
        }
      }
    }
  }
}