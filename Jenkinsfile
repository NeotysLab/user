@Library('dynatrace@master') _

def _VERSION = 'UNKNOWN'
def _TAG = 'UNKNOWN'
def _TAG_DEV = 'UNKNOWN'
def _TAG_STAGING = 'UNKNOWN'

pipeline {
  agent {
    label 'golang2'
  }
  environment {
    APP_NAME = "user"
    ARTEFACT_ID = "sockshop-" + "${env.APP_NAME}"
    DYNATRACEID="${env.DT_ACCOUNTID}"
    DYNATRACEAPIKEY="${env.DT_API_TOKEN}"
    NLAPIKEY="${env.NL_WEB_API_KEY}"
    NL_DT_TAG="app:${env.APP_NAME},environment:dev"
    OUTPUTSANITYCHECK="$WORKSPACE/infrastructure/sanitycheck.json"
    NEOLOAD_ASCODEFILE="$WORKSPACE/test/neoload/user_neoload.yaml"
    NEOLOAD_ANOMALIEDETECTIONFILE="$WORKSPACE/monspec/user_anomamlieDection.json"
    BASICCHECKURI="health"
    CUSTOMERURI="customer"
    CARDSURI="cards"
    GITORIGIN="neotyslab"
  }
  stages {
    stage('Go build') {
      steps {
        // checkout scm
        checkout([$class: 'GitSCM', 
          branches: [[name: "${env.BRANCH_NAME}"]], 
          doGenerateSubmoduleConfigurations: false, 
          extensions: [], 
          userRemoteConfigs: [[url: "https://github.com/${env.GITHUB_ORGANIZATION}/${env.APP_NAME}"]]
        ])
        script {
          _VERSION = readFile('version').trim()
          _TAG = "${env.DOCKER_REGISTRY_URL}:5000/sockshop-registry/${env.ARTEFACT_ID}"
          _TAG_DEV = "${_TAG}:${_VERSION}-${env.BUILD_NUMBER}"
          _TAG_STAGING = "${_TAG}:${_VERSION}"
        }
        container('gobuilder') {
          sh '''
            export GOPATH=$PWD

            go version

            mkdir -p src/github.com/dynatrace-sockshop/user/
            cp -R ./api src/github.com/dynatrace-sockshop/user/
            cp -R ./db src/github.com/dynatrace-sockshop/user/
            cp -R ./users src/github.com/dynatrace-sockshop/user/
            cp -R ./main.go src/github.com/dynatrace-sockshop/user/
            cp -R ./glide.* src/github.com/dynatrace-sockshop/user/
            cd src/github.com/dynatrace-sockshop/user && ls -lsa

            glide install
            go build -a -ldflags -linkmode=external -installsuffix cgo -o $GOPATH/user main.go
          '''
        }
      }
    }
    stage('Docker build') {
      when {
        expression {
          return env.BRANCH_NAME ==~ 'release/.*' || env.BRANCH_NAME ==~'master'
        }
      }
      steps {
        container('docker') {
          sh "docker build -t ${_TAG_DEV} ."
        }
      }
    }
    stage('Docker push to registry'){
      when {
        expression {
          return env.BRANCH_NAME ==~ 'release/.*' || env.BRANCH_NAME ==~'master'
        }
      }
      steps {
        container('docker') {
          withCredentials([usernamePassword(credentialsId: 'registry-creds', passwordVariable: 'TOKEN', usernameVariable: 'USER')]) {
            sh "docker login --username=anything --password=${TOKEN} ${env.DOCKER_REGISTRY_URL}:5000"
            sh "docker tag ${_TAG_DEV} ${_TAG_DEV}"
            sh "docker push ${_TAG_DEV}"
          }
        }
      }
    }
    stage('Deploy to dev namespace') {
      when {
        expression {
          return env.BRANCH_NAME ==~ 'release/.*' || env.BRANCH_NAME ==~'master'
        }
      }
      steps {
        container('kubectl') {
          sh "sed -i 's#image: .*#image: ${_TAG_DEV}#' manifest/user.yml"
          sh "kubectl -n dev apply -f manifest/user.yml"
        }
      }
    }
    stage('DT Deploy Event') {
        when {
            expression {
            return env.BRANCH_NAME ==~ 'release/.*' || env.BRANCH_NAME ==~'master'
            }
        }
        steps {
          container("curl") {
            // send custom deployment event to Dynatrace
            sh "curl -X POST \"$DT_TENANT_URL/api/v1/events?Api-Token=$DT_API_TOKEN\" -H \"accept: application/json\" -H \"Content-Type: application/json\" -d \"{ \\\"eventType\\\": \\\"CUSTOM_DEPLOYMENT\\\", \\\"attachRules\\\": { \\\"tagRule\\\" : [{ \\\"meTypes\\\" : [\\\"SERVICE\\\"], \\\"tags\\\" : [ { \\\"context\\\" : \\\"CONTEXTLESS\\\", \\\"key\\\" : \\\"app\\\", \\\"value\\\" : \\\"${env.APP_NAME}\\\" }, { \\\"context\\\" : \\\"CONTEXTLESS\\\", \\\"key\\\" : \\\"environment\\\", \\\"value\\\" : \\\"dev\\\" } ] }] }, \\\"deploymentName\\\":\\\"${env.JOB_NAME}\\\", \\\"deploymentVersion\\\":\\\"${_VERSION}\\\", \\\"deploymentProject\\\":\\\"\\\", \\\"ciBackLink\\\":\\\"${env.BUILD_URL}\\\", \\\"source\\\":\\\"Jenkins\\\", \\\"customProperties\\\": { \\\"Jenkins Build Number\\\": \\\"${env.BUILD_ID}\\\",  \\\"Git commit\\\": \\\"${env.GIT_COMMIT}\\\" } }\" "
          }
        }
    }
    stage('Start NeoLoad infrastructure') {

        steps {
                container('kubectl') {
                    script {
                     sh "kubectl create -f $WORKSPACE/infrastructure/infrastructure/neoload/lg/docker-compose.yml"
                    }
                }
        }

    }
    stage('Run health check in dev') {
      when {
        expression {
          return env.BRANCH_NAME ==~ 'release/.*' || env.BRANCH_NAME ==~'master'
        }
      }
      steps {
        echo "Waiting for the service to start..."
        sleep 300
        sh "sed -i 's/CHECK_TO_REPLACE/${BASICCHECKURI}/'  ${NEOLOAD_ASCODEFILE}"
        sh "sed -i 's/CUSTOMER_TO_REPLACE/${CUSTOMERURI}/'  ${NEOLOAD_ASCODEFILE}"
        sh "sed -i 's/CARDS_TO_REPLACE/${CARDSURI}/'  ${NEOLOAD_ASCODEFILE}"
        sh "sed -i 's/HOST_TO_REPLACE/${env.APP_NAME}.dev.svc/'  ${NEOLOAD_ASCODEFILE}"
        sh "sed -i 's/PORT_TO_REPLACE/80/'  ${NEOLOAD_ASCODEFILE}"
        sh "sed -i 's/DTID_TO_REPLACE/${DYNATRACEID}/'  ${NEOLOAD_ASCODEFILE}"
        sh "sed -i 's/APIKEY_TO_REPLACE/${DYNATRACEAPIKEY}/'  ${NEOLOAD_ASCODEFILE}"
        sh "sed -i 's,JSONFILE_TO_REPLACE,${NEOLOAD_ANOMALIEDETECTIONFILE},'  ${NEOLOAD_ASCODEFILE}"
        sh "sed -i 's/TAGS_TO_REPLACE/${NL_DT_TAG}/'  ${NEOLOAD_ASCODEFILE}"
        container('neoload') {
         script {

                      sh "mkdir -p /home/jenkins/.neotys/neoload"
                      sh "cp $WORKSPACE/infrastructure/infrastructure/neoload/license.lic /home/jenkins/.neotys/neoload/"
                      status =sh(script:"/neoload/bin/NeoLoadCmd -project $WORKSPACE/test/neoload/load_template/load_template.nlp ${NEOLOAD_ASCODEFILE} -testResultName HealthCheck_User_${BUILD_NUMBER} -description HealthCheck_User_${BUILD_NUMBER} -nlweb -L BasicCheck=$WORKSPACE/infrastructure/infrastructure/neoload/lg/remote.txt -L Population_Dynatrace_Integration=$WORKSPACE/infrastructure/infrastructure/neoload/lg/local.txt -nlwebToken $NLAPIKEY -launch BasicCheck -noGUI", returnStatus: true)

                      if (status != 0) {
                                currentBuild.result = 'FAILED'
                                error "Health check in dev failed."
                      }
         }

        }
      }
    }
    stage('Sanity Check') {
      steps {
        container('neoload') {
          script {
                 status =sh(script:"/neoload/bin/NeoLoadCmd -project $WORKSPACE/test/neoload/load_template/load_template.nlp ${NEOLOAD_ASCODEFILE}  -testResultName DynatraceSanityCheck_User_${BUILD_NUMBER} -description DynatraceSanityCheck_User_${BUILD_NUMBER} -nlweb -L  Population_Dynatrace_SanityCheck=$WORKSPACE/infrastructure/infrastructure/neoload/lg/local.txt -nlwebToken $NLAPIKEY -variables host=${env.APP_NAME}.dev,port=80 -launch DYNATRACE_SANITYCHECK  -noGUI", returnStatus: true)

                 if (status != 0) {
                      currentBuild.result = 'FAILED'
                      error "Health check in dev failed."
                 }
           }
         }
         container('git') {
           echo "push ${OUTPUTSANITYCHECK}"
           //---add the push of the sanity check---
           withCredentials([usernamePassword(credentialsId: 'git-credentials-acm', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
               sh "git config --global user.email ${env.GITHUB_USER_EMAIL}"
               sh "git add ${OUTPUTSANITYCHECK}"
               sh "git commit -m 'Update Sanity_Check_${BUILD_NUMBER} ${env.APP_NAME} version ${env.VERSION}'"
               sh "git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${env.GITHUB_ORGANIZATION}/user ${GITORIGIN} master"
           }
         }

      }
    }
    stage('Run functional check in dev') {
      when {
        expression {
          return env.BRANCH_NAME ==~ 'release/.*' || env.BRANCH_NAME ==~'master'
        }
      }
      steps {
         container('neoload') {
              script {

                    status =sh(script:"/neoload/bin/NeoLoadCmd -project $WORKSPACE/test/neoload/load_template/load_template.nlp ${NEOLOAD_ASCODEFILE} -testResultName FuncCheck_User_${BUILD_NUMBER} -description FuncCheck_User_${BUILD_NUMBER} -nlweb -L CatalogueLoad=$WORKSPACE/infrastructure/infrastructure/neoload/lg/remote.txt -L Population_Dynatrace_Integration=$WORKSPACE/infrastructure/infrastructure/neoload/lg/local.txt -nlwebToken $NLAPIKEY -launch UserLoad -noGUI", returnStatus: true)

                    if (status != 0) {
                              currentBuild.result = 'FAILED'
                              error "Health check in dev failed."
                    }

              }
            }
      }
    }
    stage('Mark artifact for staging namespace') {
      when {
        expression {
          return env.BRANCH_NAME ==~ 'release/.*'
        }
      }
      steps {
        container('docker'){
          sh "docker tag ${_TAG_DEV} ${_TAG_STAGING}"
          sh "docker push ${_TAG_STAGING}"
        }
      }
    }
    stage('Deploy to staging') {
      when {
        beforeAgent true
        expression {
          return env.BRANCH_NAME ==~ 'release/.*'
        }
      }
      steps {
        build job: "k8s-deploy-staging",
          parameters: [
            string(name: 'APP_NAME', value: "${env.APP_NAME}"),
            string(name: 'TAG_STAGING', value: "${_TAG_STAGING}"),
            string(name: 'VERSION', value: "${_VERSION}")
          ]
      }
    }
  }
  post {
          always {
            container('kubectl') {
                   script {
                    echo "delete neoload infrastructure"
                    sh "kubectl delete svc nl-lg-user -n cicd"
                    sh "kubectl delete pod nl-lg-user -n cicd --grace-period=0 --force"
                   }
            }
          }

        }
}
