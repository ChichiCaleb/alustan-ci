
# Continuous Integration (CI) and automated release best practices

>  #### **alustan-ci** aims to implement Continuous Integration (CI) and automated release best practices using [Calcom](https://github.com/calcom/cal.com) monorepo as reference application

![architecture](architecture.svg)


## Features

  - ##### Production grade nextjs monorepo dockerfile 

  - ##### docker compose for local testing

  - ##### unit test in github workflow

  - ##### sample integration test in github workflow

  - ##### vulnerability scan with Trivy

  - ##### Automated Changelog generation using [conventionalcommits](https://www.conventionalcommits.org/en/v1.0.0/)

  - ##### automated software pre-release and release for every pull request and merge request to the main branch respectively, ensure to use conventional commit recommended  pattern for automated semantic versioining.

  - ##### builds and push docker image to GHCR and docker hub for test and final production image respectively

  - ##### pushes image label and tags to pull-request discussion section for reference purpose
 
  - ##### tags pull request images with `preview` label to be used by argocd pull requst generator for preview environment
 
  - ##### updates docker compose `image tag` 

  - ##### updates kubernetes manifest `image tag` in a seperate repo


## Getting Started

To run **alustan-ci**, please follow these simple steps.

### Prerequisites

Here is what you need to be able to run **alustan-ci**.

> - **linux virtual machine**

> - **`DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`**

> - **GitHub organization admin token**

> - Generate the above admin token by checking the following scopes:
       `Repo`
       `workflow`
       `write package`
       `admin:org`

> - **The generated credentials will be needed during the `setup script` execution**

### Setup

1. Install and run the `alustan/alustan-ci` setup script 

```sh
  rm -f setup.sh && \
      curl -o setup.sh https://raw.githubusercontent.com/alustan/alustan-ci/main/setup.sh && \
      chmod +x setup.sh && \
     ./setup.sh
```

2. The script provisions everything, pushes the customized codebase to your personal repository and opens the forked repo in the browser 

3. On **github UI** enable organization or repository `Read and write permissions` 

4. On **github UI** Open `Actions` and enable GitHub Actions.

4. Run the workflow using `workflow_dispatch` in the UI , alternatively push changes to main branch
    
5. create a pull request to the main branch with subsequent merge and observe a trigger of ci workflow in github actions tab, with generation of release,prerelease and changelog notes
   
6. start the services in docker compose

   ```sh
   docker compose -f infra/docker/web/docker-compose.yaml up
   ```

7. view the app in the browser on `http://localhost:3000`
