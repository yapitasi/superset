#!/bin/bash

# Env Vars
POSTGRES_USER="superset"
POSTGRES_PASSWORD=$(openssl rand -base64 12)  # Generate a random 12-character password
POSTGRES_DB="superset"
SECRET_KEY=$(openssl rand -base64 32)  # Generate a random 32-character secret key

# Script Vars
REPO_URL="https://github.com/yapitasi/superset.git"
APP_DIR=~/superset
SWAP_SIZE="1G"  # Swap size of 1GB
SUPERSET_CONFIG_PATH="$APP_DIR/superset_config_docker.py"
# Update package list and upgrade existing packages
sudo apt update && sudo apt upgrade -y

# Add Swap Space
echo "Adding swap space..."
sudo fallocate -l $SWAP_SIZE /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Install Docker
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
sudo apt update
sudo apt install docker-ce -y

# Install Docker Compose
sudo rm -f /usr/local/bin/docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Wait for the file to be fully downloaded before proceeding
if [ ! -f /usr/local/bin/docker-compose ]; then
  echo "Docker Compose download failed. Exiting."
  exit 1
fi

sudo chmod +x /usr/local/bin/docker-compose

# Ensure Docker Compose is executable and in path
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Verify Docker Compose installation
docker-compose --version
if [ $? -ne 0 ]; then
  echo "Docker Compose installation failed. Exiting."
  exit 1
fi

# Ensure Docker starts on boot and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Clone the Git repository
if [ -d "$APP_DIR" ]; then
  echo "Directory $APP_DIR already exists. Pulling latest changes..."
  cd $APP_DIR && git pull
else
  echo "Cloning repository from $REPO_URL..."
  git clone $REPO_URL $APP_DIR
  cd $APP_DIR
fi


SQLALCHEMY_DATABASE_URI=postgresql+psycopg2://$POSTGRES_USER:$POSTGRES_PASSWORD@172.17.0.1:5432/$POSTGRES_DB
# Create the .env file inside the app directory (~/myapp/.env)
echo "SQLALCHEMY_DATABASE_URI=\"$SQLALCHEMY_DATABASE_URI\"" > "$SUPERSET_CONFIG_PATH"
echo "SECRET_KEY=\"$SECRET_KEY" >> "$SUPERSET_CONFIG_PATH\""


# Build and run the Docker containers from the app directory (~/myapp)
cd $APP_DIR
export TAG=4.0.2
sudo docker-compose -f docker-compose-non-dev.yml up --build -d
sudo docker-compose -f docker-compose-non-dev.yml exec superset superset set_database_uri --database_name $POSTGRES_DB --uri "$SQLALCHEMY_DATABASE_URI"

# Check if Docker Compose started correctly
if ! sudo docker-compose ps | grep "Up"; then
  echo "Docker containers failed to start. Check logs with 'docker-compose logs'."
  exit 1
fi

# Output final message
echo "Deployment complete. Your Next.js app and PostgreSQL database are now running.
Next.js is available at https://$DOMAIN_NAME, and the PostgreSQL database is accessible from the web service.

The .env file has been created with the following values:
- POSTGRES_USER
- POSTGRES_PASSWORD (randomly generated)
- POSTGRES_DB
- SQLALCHEMY_DATABASE_URI
- SECRET_KEY
"
