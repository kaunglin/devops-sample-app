// Builds the image with Kaniko (no Docker daemon exists inside the cluster),
// pushes it to the homelab registry under an immutable short-SHA tag, then
// bumps that tag in the GitOps repo so Argo CD picks the change up.
pipeline {
  agent {
    kubernetes {
      defaultContainer 'kaniko'
      yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.23.2-debug
      imagePullPolicy: IfNotPresent
      command: ["/busybox/cat"]
      tty: true
      resources:
        requests:
          cpu: "250m"
          memory: "512Mi"
        limits:
          cpu: "1"
          memory: "1Gi"
    - name: git
      image: alpine/git:2.45.2
      command: ["cat"]
      tty: true
      resources:
        requests:
          cpu: "50m"
          memory: "64Mi"
'''
    }
  }

  environment {
    // Inside the cluster the registry answers to its container name. Manifests
    // reference localhost:5001 instead; containerd rewrites that to this same
    // address, so both names resolve to identical blobs.
    REGISTRY  = 'homelab-registry:5000'
    IMAGE     = 'sample-app'
    GITOPS_REPO = 'https://github.com/kaunglin/devops-argocd.git'
    GITOPS_PATH = 'homelab-apps/sample-app/deployment.yaml'
  }

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  stages {
    stage('Resolve tag') {
      steps {
        script {
          // Immutable tag. Never :latest -- Argo CD cannot detect drift or roll
          // back against a floating tag.
          env.TAG = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          echo "Building ${env.IMAGE}:${env.TAG}"
        }
      }
    }

    stage('Build and push') {
      steps {
        container('kaniko') {
          sh '''
            /kaniko/executor \
              --context "$(pwd)" \
              --dockerfile Dockerfile \
              --destination "${REGISTRY}/${IMAGE}:${TAG}" \
              --build-arg "BUILD_VERSION=${TAG}" \
              --insecure \
              --skip-tls-verify \
              --single-snapshot
          '''
        }
      }
    }

    stage('Bump tag in GitOps repo') {
      steps {
        container('git') {
          withCredentials([usernamePassword(
              credentialsId: 'github-token',
              usernameVariable: 'GIT_USER',
              passwordVariable: 'GIT_TOKEN')]) {
            sh '''
              set -e
              rm -rf gitops && git clone --depth 1 "${GITOPS_REPO}" gitops
              cd gitops
              git config user.email "jenkins@homelab.local"
              git config user.name  "Jenkins (homelab)"

              sed -i "s#image: localhost:5001/${IMAGE}:.*#image: localhost:5001/${IMAGE}:${TAG}#" "${GITOPS_PATH}"

              if git diff --quiet; then
                echo "Image tag already ${TAG}; nothing to commit."
                exit 0
              fi

              git add "${GITOPS_PATH}"
              git commit -m "sample-app: deploy ${TAG}

Built by Jenkins build ${BUILD_NUMBER} from ${GIT_COMMIT}."
              git push "https://${GIT_USER}:${GIT_TOKEN}@github.com/kaunglin/devops-argocd.git" HEAD:main
              echo "Pushed image tag ${TAG} to the GitOps repo."
            '''
          }
        }
      }
    }
  }

  post {
    success { echo "Done. Argo CD will sync sample-app to ${env.TAG}." }
    failure { echo "Build failed - see the stage log above." }
  }
}
