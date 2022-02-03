node{
    try{
        def mavenHome
        def mavenCMD
        def docker
        def dockerCMD
        
        stage('Preparation'){
            echo "Preparing the Jenkins environment with required tools..."
            mavenHome = tool name: 'maven', type: 'maven'
            mavenCMD = "${mavenHome}/bin/mvn"
            docker = tool name: 'docker', type: 'org.jenkinsci.plugins.docker.commons.tools.DockerTool'
            dockerCMD = "/usr/bin/docker"
        }
        
        stage('git checkout'){
            echo "Checking out the code from git repository..."
            git 'https://github.com/anupabenny/batch10.git'
        }
        
        stage('Build, Test and Package'){
            echo "Building the application..."
            sh "${mavenCMD} clean package"
        }
        
        stage('Sonar Scan'){
            echo "Scanning application for vulnerabilities..."
            sh "${mavenCMD} sonar:sonar -Dsonar.host.url=http://ec2-34-227-111-128.compute-1.amazonaws.com:9000/"
        }
            
        stage('Publish HTML reports'){
            echo "Publishing HTML reports"
            publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: '/var/lib/jenkins/workspace/mainproject/target/surefire-reports', reportFiles: 'com.TestMessageController.txt', reportName: 'html_report', reportTitles: 'html_report'])
        }
        
        stage('Build Docker Image'){
            echo "Building docker image for my-test-app application ..."
            sh "sudo ${dockerCMD} build -t anupabenny/bootcamp:tomcat-bootcamp2-image ."
        }
        stage('Push Docker Image to Docker Hub'){
            echo "Pushing image to docker hub"
            withCredentials([usernamePassword(credentialsId: 'dockerhub', passwordVariable: 'dockerHubPwd', usernameVariable: '')]) {
            sh "sudo ${dockerCMD} login -u anupabenny -p ${dockerHubPwd}"
            sh "sudo ${dockerCMD} push anupabenny/bootcamp:tomcat-devopsE3-image"
            }
        }
        stage('Deploy Application'){
            echo "Installing desired software.."
            echo "Bring docker service up and running"
            echo "Deploying addressbook application"
            ansiblePlaybook credentialsId: 'new-cred', disableHostKeyChecking: true, installation: 'ansible', inventory: '/etc/ansible/hosts', playbook: 'deploy-playbook.yml'
        }
    currentBuild.result = 'SUCCESS'
    }
catch(Exception err){
    echo "Exception occured..."
    currentBuild.result = 'FAILURE'
    emailext to: 'anupabenny90@gmail.com',
    subject: "Status of pipeline: ${currentBuild.fullDisplayName}",
    body: "${env.BUILD_URL} has result - ${currentBuild.result}"
}
finally {
        echo "completed build"
        emailext to: 'anupabenny90@gmail.com',
        subject: "Status of pipeline: ${currentBuild.fullDisplayName}",
        body: "${env.BUILD_URL} has result - ${currentBuild.result}"
    }
}
