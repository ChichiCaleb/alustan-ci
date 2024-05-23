#!/bin/bash

set -e

# Function to install Docker
function install_docker() {
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce
    sudo service docker start
}

# Function to install GitHub CLI
function install_gh_cli() {
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install -y wget)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install -y gh
}

# Function to check if an account is an organization
function is_organization() {
    local account="$1"
    local org_info
    org_info="$(curl -s -H "Authorization: token $GH_TOKEN" "https://api.github.com/orgs/$account")"
    if [[ "$org_info" =~ \"name\" ]]; then
        return 0 # Account is an organization
    else
        return 1 # Account is not an organization
    fi
}

# Function to check and configure SSH
function check_and_clone_ssh() {
    check_ssh_configured
    if [ $? -eq 0 ]; then
        echo "SSH is configured. Attempting to clone the repository using SSH..."
        git clone git@github.com:$repo_name.git
        return $?
    else
        echo "SSH is not configured. Please configure SSH and try again."
        return 1
    fi
}

# Function to create Docker user secret
function create_docker_user_secret() {
    if is_organization "${GITHUB_ORG}"; then
        gh secret set DOCKERHUB_USERNAME --body "$DOCKERHUB_USERNAME" --org "${GITHUB_ORG}" --visibility all
    else
        gh secret set DOCKERHUB_USERNAME --body "$DOCKERHUB_USERNAME" --visibility all
    fi
}

# Function to create Docker token secret
function create_docker_token_secret() {
    if is_organization "${GITHUB_ORG}"; then
        gh secret set DOCKERHUB_TOKEN --body "$DOCKERHUB_TOKEN" --org "${GITHUB_ORG}" --visibility all
    else
        gh secret set DOCKERHUB_TOKEN --body "$DOCKERHUB_TOKEN" --visibility all
    fi
}



# Function to check if SSH is configured
function check_ssh_configured() {
    echo "Checking SSH configuration with GitHub..."

    # Attempt SSH connection to GitHub
    ssh_output=$(ssh -T git@github.com 2>&1)
    local ssh_exit_code=$?

    if [[ $ssh_exit_code -ne 1 ]]; then
        echo "Error: Unable to authenticate with GitHub using SSH."
        return 1
    fi

    if echo "$ssh_output" | grep -q "You've successfully authenticated"; then
        echo "SSH is configured and authenticated with GitHub."
        return 0
    else
        echo "SSH is not configured or authenticated with GitHub."
        return 1
    fi
}

# Function to fork repository
function repo_fork() {
    local repo_name="$GITHUB_ORG/$REPO"
    
    echo "Checking if repository $repo_name exists..."
    if gh repo view "$repo_name" >/dev/null 2>&1; then
        echo "Repository $repo_name exists"
    else
        echo "Forking repository alustan/alustan-ci."
        if is_organization "${GITHUB_ORG}"; then
            gh repo fork alustan/alustan-ci --org "${GITHUB_ORG}" --fork-name "${REPO}" --clone=false
        else
            gh repo fork alustan/alustan-ci --fork-name "${REPO}" --clone=false
        fi
    fi
}



# Function to clone repository
function repo_clone() {
    local repo_name="$GITHUB_ORG/$REPO"
    local clone_dir="./$REPO"
    
    echo "Checking if the repository has already been cloned..."
    if [ -d "$clone_dir" ]; then
        echo "Repository $repo_name has already been cloned. Updating repository..."
        cd "$clone_dir" || { echo "Failed to change directory to $clone_dir"; return 1; }

        echo "Fetching latest changes..."
        if ! git fetch origin; then
            echo "Failed to fetch latest changes from origin."
            return 1
        fi

        echo "Pulling latest changes with rebase..."
        if ! git pull origin main --rebase; then
            echo "Rebasing failed."
            return 1
        fi

        echo "Updating local branches to track remote branches..."
        git fetch --all
        git pull --all
    else
        echo "Cloning repository $repo_name."
        if [ "$GIT_SSH" = "true" ]; then
            if ! check_and_clone_ssh; then
                
                echo "Attempting to clone the repository using HTTPS..."
                if ! git clone https://github.com/$repo_name.git; then
                    echo "Cloning using HTTPS failed"
                      return 1
                fi
            fi
        else
            if ! git clone https://github.com/$repo_name.git; then
                echo "Cloning using HTTPS failed. Attempting SSH..."
                if ! check_and_clone_ssh; then
                    echo "Cloning using SSH also failed."
                    return 1
                fi
            fi
        fi
        cd "$clone_dir" || { echo "Failed to change directory to $clone_dir"; return 1; }
    fi

         echo "Setting upstream remote..."
    if ! git remote | grep -q upstream; then
        if ! git remote add upstream "https://github.com/alustan/alustan-ci.git"; then
            echo "Failed to add upstream remote."
            return 1
        fi
    fi

    echo "Repository setup complete."
}


##########################################################################################################

###########################################################################################################



# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "Curl is not installed. Installing..."
    sudo apt install -y curl
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
sudo apt update
sudo apt install git
fi
# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing..."
    install_docker
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo "Docker Compose is not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI is not installed. Installing..."
    install_gh_cli
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "yq is not installed. Installing..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod a+x /usr/local/bin/yq
fi

# Check if Gum is installed
if ! command -v gum &> /dev/null; then
    echo "Gum not found. Installing..."
    echo 'deb [trusted=yes] https://repo.charm.sh/apt/ /' | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install -y gum
fi

##########################################################################################################

###########################################################################################################



gum style \
    --foreground 212 --border-foreground 212 --border double \
    --margin "1 2" --padding "2 4" \
    'alustan/alustan-ci aims to implement Continuous Integration (CI) and 
automated release best practices using Calcom monorepo as reference application'

gum confirm 'Are you ready to bootstrap a personal fork of alustan-ci repo?' || exit 0

echo "Enter GitHub organization or username"
GITHUB_ORG=$(gum input --placeholder "Enter GitHub organization/username" --value "$GITHUB_ORG")

gum confirm "Do you wish to rename this repo? Choose \"No\" if you want to keep the upstream repo name." \
    && echo "Please enter repo name" \
    && REPO_NAME=$(gum input --placeholder "Please enter repo name")

REPO="${REPO_NAME:-alustan-ci}"
export REPO

echo "Please enter GitHub organization admin token"
ORG_ADMIN_TOKEN=$(gum input --placeholder "Please enter GitHub organization admin token." --password)
export GH_TOKEN=$ORG_ADMIN_TOKEN

if gum confirm "Do you wish to enable git ssh authentication (RECOMMENDED- LARGE REPO). Ensure git ssh is already setup"; then
    GIT_SSH=true
    export GH_GIT_PROTOCOL=ssh
    sudo gh config set git_protocol ssh
    echo "GitHub CLI authenticated and configured to use SSH."
else
    GIT_SSH=false
fi

# Example usage of the function
echo "Starting repo_fork_clone..."
repo_fork
repo_clone || true  # Allow script to continue even if cloning fails

if is_organization "${GITHUB_ORG}"; then
    gh secret set RELEASE_MAIN --body "$GH_TOKEN" --org "${GITHUB_ORG}" --visibility all
else
    gh secret set RELEASE_MAIN --body "$GH_TOKEN" --visibility all
fi

gum confirm "We need to create GitHub secret DOCKERHUB_USERNAME. Choose \"No\" if you already have it." \
    && echo "Please enter Docker Hub user" \
    && DOCKERHUB_USERNAME=$(gum input --placeholder "Please enter Docker Hub user") \
    && export DOCKERHUB_USER=$DOCKERHUB_USERNAME \
    && create_docker_user_secret

gum confirm "We need to create GitHub secret DOCKERHUB_TOKEN. Choose \"No\" if you already have it." \
    && echo "Please enter Docker Hub token" \
    && DOCKERHUB_TOKEN=$(gum input --placeholder "Docker access token " --password) \
    && create_docker_token_secret

yq --inplace ".services.calcom.image = \"${DOCKERHUB_USER}/calcom\"" infra/docker/web/docker-compose.yaml

cp infra/docker/web/.env.example infra/docker/web/.env

# Confirm with the user about the k8s manifest repo
if gum confirm "Do you have a k8s manifest repo and wish to automate updating of image tag. Choose \"No\" if not setup."; then
    echo "Please enter name of manifest repo"
    REMOTE_REPO_NAME=$(gum input --placeholder "Name of manifest repo")
    export REMOTE_REPO=$REMOTE_REPO_NAME

    echo "Please enter name of workflow to run in manifest repo"
    REMOTE_WORKFLOW_NAME=$(gum input --placeholder "Name of workflow")
    export REMOTE_WORKFLOW=$REMOTE_WORKFLOW_NAME

      yq eval '
        (.jobs."tag-manifest-update-compose".steps[] | select(.name == "Set default values for manifest tag").run) = 
        "echo \"PUSH_MANIFEST_TAG=true\" >> $GITHUB_ENV\n" +
        "echo \"REMOTE_REPO='$REMOTE_REPO'\" >> $GITHUB_ENV\n" +
        "echo \"REMOTE_WORKFLOW='$REMOTE_WORKFLOW'\" >> $GITHUB_ENV" +
        "echo \"PREVIEW_WORKFLOW=''\" >> $GITHUB_ENV" +
        "echo \"ENABLE_PREVIEW='false'\" >> $GITHUB_ENV" 

        ' -i .github/workflows/ci.yml

    # Confirm with the user about the E2E test with Preview Environment
    if gum confirm "Do you wish to implement Preview Environment. Ensure preview manifest and workflow is setup. Choose \"No\" if not setup."; then
        echo "Please enter name of \"PREVIEW\" workflow to run in manifest repo"
        PREVIEW_WORKFLOW_NAME=$(gum input --placeholder "Name of workflow")
        export PREVIEW_WORKFLOW=$PREVIEW_WORKFLOW_NAME

      yq eval '
        (.jobs."tag-manifest-update-compose".steps[] | select(.name == "Set default values for manifest tag").run) = 
        "echo \"PUSH_MANIFEST_TAG=true\" >> $GITHUB_ENV\n" +
        "echo \"REMOTE_REPO='$REMOTE_REPO'\" >> $GITHUB_ENV\n" +
        "echo \"ENABLE_PREVIEW='true'\" >> $GITHUB_ENV" +
        "echo \"PREVIEW_WORKFLOW='$PREVIEW_WORKFLOW'\" >> $GITHUB_ENV" +
        "echo \"REMOTE_WORKFLOW=''\" >> $GITHUB_ENV"
        ' -i .github/workflows/ci.yml

    fi
fi

set +e

git add .
git commit -m "feat: $REPO bootstrap"
# Check if the remote "origin" already exists
if ! git remote get-url origin >/dev/null 2>&1; then
    # If not, set the remote URL
    git remote add origin https://github.com/$GITHUB_ORG/alustan-ci.git
fi
git remote set-url origin  https://$GITHUB_ORG@github.com/$GITHUB_ORG/$REPO.git
git branch -M main
git push https://$GITHUB_ORG@github.com/$GITHUB_ORG/$REPO.git 

set -e

cd ..

echo "Attempting to open the bootstrap repo in the browser..." 

gh repo view --web $GITHUB_ORG/$REPO 2>/dev/null

gum style \
    --foreground 212 --border-foreground 212 --border double \
    --margin "1 2" --padding "2 4" \
    'Repo is ready!
Open \"Actions\" and enable GitHub Actions'