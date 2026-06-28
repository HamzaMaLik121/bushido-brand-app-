// Jenkinsfile
// ─────────────────────────────────────────────────────────────────────────────
// Bushido Brand — Full CI/CD Pipeline
//
// This file orchestrates the pipeline for BOTH services in this monorepo:
//   - backend/  (Flask API — port 5000, health: /api/health)
//   - frontend/ (Nginx static site — port 80, health: /)
//
// All stage implementation lives in the shared library.
// This file only sets config and calls the functions.
// ─────────────────────────────────────────────────────────────────────────────

@Library('Shared@main') _

pipeline {
    agent { label 'docker-agent' }

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        // ─── Backend ───────────────────────────────────────────────────────
        BACKEND_APP_NAME        = 'backend'
        BACKEND_DOCKER_REPO     = 'bushidobrand/bushido-brand-backend'
        BACKEND_HELM_VALUE_PATH = 'bushido-brand-pipeline/gitops-repo/charts/backend/values.yaml'
        BACKEND_SONAR_KEY       = 'bushido-brand-backend'
        BACKEND_ARGO_APP        = 'bushido-brand-backend'
        BACKEND_DOCKERFILE      = 'backend/Dockerfile'
        BACKEND_BUILD_CONTEXT   = 'backend'
        // Note: BACKEND_IMAGE is set at runtime in the checkout stage

        // ─── Frontend ──────────────────────────────────────────────────────
        FRONTEND_APP_NAME        = 'frontend'
        FRONTEND_DOCKER_REPO     = 'bushidobrand/bushido-brand-frontend'
        FRONTEND_HELM_VALUE_PATH = 'bushido-brand-pipeline/gitops-repo/charts/frontend/values.yaml'
        FRONTEND_SONAR_KEY       = 'bushido-brand-frontend'
        FRONTEND_ARGO_APP        = 'bushido-brand-frontend'
        FRONTEND_DOCKERFILE      = 'frontend/Dockerfile'
        FRONTEND_BUILD_CONTEXT   = 'frontend'
        // Note: FRONTEND_IMAGE is set at runtime in the checkout stage
    }

    stages {
        // ╔════════════════════════════════════════════════════════════════╗
        // ║              CI — Continuous Integration                      ║
        // ║         Runs on EVERY branch                                  ║
        // ╚════════════════════════════════════════════════════════════════╝

        stage('CI — Checkout') {
            steps {
                script {
                    checkout([$class: 'GitSCM', branches: [[name: '*/main']], userRemoteConfigs: [[url: 'https://github.com/HamzaMaLik121/bushido-brand-app-.git', credentialsId: 'Github-cred']]])
                    env.GIT_COMMIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD 2>/dev/null || true').trim()
                    if (!env.GIT_COMMIT_SHORT) env.GIT_COMMIT_SHORT = 'unknown'
                    env.BACKEND_IMAGE  = "${env.BACKEND_DOCKER_REPO}:${env.GIT_COMMIT_SHORT}"
                    env.FRONTEND_IMAGE = "${env.FRONTEND_DOCKER_REPO}:${env.GIT_COMMIT_SHORT}"
                    echo "Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "Backend image:  ${env.BACKEND_IMAGE}"
                    echo "Frontend image: ${env.FRONTEND_IMAGE}"
                }
            }
        }

        // ─── BACKEND: OWASP + SONARQUBE ────────────────────────────────────
        stage('CI — Backend: OWASP & SonarQube') {
            parallel {
                stage('OWASP Dependency Check') {
                    steps {
                        dir('backend') {
                            runOwaspCheck(
                                appName: 'bushido-brand-backend',
                                suppressionPath: '../devsecops/owasp/suppressions.xml'
                            )
                        }
                    }
                    post { always { dependencyCheckPublisher pattern: 'backend/reports/dependency-check-report.xml' } }
                }
                stage('SonarQube Analysis') {
                    steps {
                        dir('backend') {
                            runSonarScan(projectKey: env.BACKEND_SONAR_KEY)
                        }
                    }
                }
            }
        }

        // ─── FRONTEND: SONARQUBE ────────────────────────────────────────────
        stage('CI — Frontend: SonarQube') {
            steps {
                dir('frontend') {
                    runSonarScan(projectKey: env.FRONTEND_SONAR_KEY)
                }
            }
        }

        // ─── QUALITY GATE — checks BOTH backend + frontend results ──────────
        stage('CI — SonarQube Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ─── BACKEND: BUILD + TRIVY ─────────────────────────────────────────
        stage('CI — Backend: Build & Scan') {
            parallel {
                stage('Docker Build') {
                    steps {
                        script {
                            buildDockerImage(
                                fullImage: env.BACKEND_IMAGE,
                                dockerfile: env.BACKEND_DOCKERFILE,
                                context: env.BACKEND_BUILD_CONTEXT
                            )
                        }
                    }
                }
                stage('Trivy Scan') {
                    steps {
                        runTrivyScan(fullImage: env.BACKEND_IMAGE, reportName: 'backend-trivy-report.json')
                    }
                    post { always { archiveArtifacts artifacts: 'backend-trivy-report.json', allowEmptyArchive: true } }
                }
            }
        }

        // ─── FRONTEND: BUILD + TRIVY ────────────────────────────────────────
        stage('CI — Frontend: Build & Scan') {
            parallel {
                stage('Docker Build') {
                    steps {
                        script {
                            buildDockerImage(
                                fullImage: env.FRONTEND_IMAGE,
                                dockerfile: env.FRONTEND_DOCKERFILE,
                                context: env.FRONTEND_BUILD_CONTEXT
                            )
                        }
                    }
                }
                stage('Trivy Scan') {
                    steps {
                        runTrivyScan(fullImage: env.FRONTEND_IMAGE, reportName: 'frontend-trivy-report.json')
                    }
                    post { always { archiveArtifacts artifacts: 'frontend-trivy-report.json', allowEmptyArchive: true } }
                }
            }
        }

        // ╔════════════════════════════════════════════════════════════════╗
        // ║         CD — Continuous Delivery / Deployment                  ║
        // ║ Runs ONLY on main/master/release/* — after CI passes           ║
        // ╚════════════════════════════════════════════════════════════════╝

        // ─── PUSH TO DOCKER HUB ─────────────────────────────────────────────
        stage('CD — Push to Docker Hub') {
            when { branch pattern: "^(main|master|release/.*)$", comparator: "REGEXP" }
            parallel {
                stage('Push Backend') {
                    steps { pushToDockerHub(fullImage: env.BACKEND_IMAGE) }
                }
                stage('Push Frontend') {
                    steps { pushToDockerHub(fullImage: env.FRONTEND_IMAGE) }
                }
            }
        }

        // ─── UPDATE GITOPS REPO ─────────────────────────────────────────────
        stage('CD — Update GitOps') {
            when { branch pattern: "^(main|master|release/.*)$", comparator: "REGEXP" }
            parallel {
                stage('Update Backend') {
                    steps {
                        updateGitOps(
                            gitOpsRepo: 'github.com/HamzaMaLik121/bushido-brand-app-.git',
                            helmValuePath: env.BACKEND_HELM_VALUE_PATH,
                            imageTag: env.GIT_COMMIT_SHORT,
                            appName: env.BACKEND_APP_NAME,
                            gitOpsBranch: 'main'
                        )
                    }
                }
                stage('Update Frontend') {
                    steps {
                        updateGitOps(
                            gitOpsRepo: 'github.com/HamzaMaLik121/bushido-brand-app-.git',
                            helmValuePath: env.FRONTEND_HELM_VALUE_PATH,
                            imageTag: env.GIT_COMMIT_SHORT,
                            appName: env.FRONTEND_APP_NAME,
                            gitOpsBranch: 'main'
                        )
                    }
                }
            }
        }

        // ─── ARGOCD SYNC ────────────────────────────────────────────────────
        stage('CD — ArgoCD Sync') {
            when { branch pattern: "^(main|master|release/.*)$", comparator: "REGEXP" }
            parallel {
                stage('Sync Backend') {
                    steps { syncArgoCD(argoApp: env.BACKEND_ARGO_APP, argoAutoSync: false) }
                }
                stage('Sync Frontend') {
                    steps { syncArgoCD(argoApp: env.FRONTEND_ARGO_APP, argoAutoSync: false) }
                }
            }
        }
    }

    post {
        success {
            echo "Slack: SUCCESS for Bushido Brand [${env.GIT_COMMIT_SHORT}]"
        }
        failure {
            echo "Slack: FAILURE for Bushido Brand [${env.GIT_COMMIT_SHORT}]"
        }
        always {
            cleanWs()
        }
    }
}
