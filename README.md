# Compvalidator
A project to validate compatibility of tools, code and thought process.

## Projects
  - Devops and Pipelines
  - Tool development in Python 
  - An observability setup
  - A system integration

### 1.0 Devops And Pipeline
Create a packaging pipeline which will compile a java code and package it inside a debian13 container image that will be shipped to production for deployment. 

  - Build Flow
    - There will be a code repo in GitHub
    - Based on code release from master, the Jenkins pipeline will be triggered
    - It will pull the code, compile and if the build is successful then it will package it in the container
    - For code compilation, all required binaries will be in a container.
      - Nothing should be there in the provision server
      - Jenkins itself should run as a container based deployment. 
    - Packaged container will be pushed to the docker registry with same release tag that was used for the build
    - Release tag format: release-1.2.3 where 1.2.3 will be the pom version of java cod
# Integration pipeline test

# Push Test
# Push Test
# Push Test
# Push Test
