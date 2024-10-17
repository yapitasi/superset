#!/bin/bash

# Env Vars for Superset
POSTGRES_USER="superset"
POSTGRES_PASSWORD="**CHANGE_THIS_PASSWORD**"  # Generate a random password
POSTGRES_DB="superset"
SECRET_KEY="**CHANGE_THIS_SECRET_KEY**"  # Generate a random 32-character secret key

# Script Vars for Superset
REPO_URL="https://github.com/yapitasi/superset.git"
APP_DIR=/opt/superset
SWAP_SIZE="1G"  # Swap size of 1GB
SUPERSET_CONFIG_PATH="$APP_DIR/docker/pythonpath_dev/superset_config_docker.py"


# Add PostgreSQL repository
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Add Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y

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

# Function to install PostgreSQL
install_postgresql() {
    echo "Installing PostgreSQL..."
    sudo apt install -y postgresql postgresql-contrib
}

# Configure PostgreSQL for remote access
configure_postgresql() {
    echo "Configuring PostgreSQL to listen on all interfaces..."
    PG_CONF=$(sudo find /etc/postgresql/ -name postgresql.conf | sort | tail -n 1)
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" $PG_CONF

    echo "Allowing remote connections..."
    PG_HBA=$(sudo find /etc/postgresql/ -name pg_hba.conf | sort | tail -n 1)
    echo "host    all             all             0.0.0.0/0            md5" | sudo tee -a $PG_HBA > /dev/null
}

# Function to restart PostgreSQL service
restart_postgresql() {
    echo "Restarting PostgreSQL service..."
    sudo systemctl restart postgresql
}

# Function to create PostgreSQL user and database
create_user_and_db() {
    echo "Creating PostgreSQL user and database..."
    sudo -u postgres psql -c "CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';"
    sudo -u postgres psql -c "CREATE DATABASE $POSTGRES_DB OWNER $POSTGRES_USER;"
}

# Install PostgreSQL and set up user/db
echo "Setting up PostgreSQL..."
install_postgresql
configure_postgresql
restart_postgresql
create_user_and_db

# Check if docker installed
echo "Checking if Docker is installed..."
docker-compose --version
if [ $? -ne 0 ]; then

  # Install Docker

  sudo apt install docker-ce -y

  # Install Docker Compose
  sudo rm -f /usr/local/bin/docker-compose
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
else
  echo "Docker Compose is already installed. Skipping..."
fi
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

# Set up SQLAlchemy URI and Secret Key in Superset config
SQLALCHEMY_DATABASE_URI=postgresql+psycopg2://$POSTGRES_USER:$POSTGRES_PASSWORD@172.17.0.1:5432/$POSTGRES_DB
echo "SQLALCHEMY_DATABASE_URI=\"$SQLALCHEMY_DATABASE_URI\"" > $SUPERSET_CONFIG_PATH
echo "SECRET_KEY=\"$SECRET_KEY\"" >> $SUPERSET_CONFIG_PATH

# Build and run the Docker containers from the app directory
cd $APP_DIR
chmod +x docker/*.sh

export SUPERSET_ENV=production
export TAG=f5ae176
export SUPERSET_CONFIG_PATH=$APP_DIR/superset_config.py


sudo docker-compose up --build -d

#sudo docker-compose exec superset superset set_database_uri --database_name $POSTGRES_DB --uri "$SQLALCHEMY_DATABASE_URI"


# Check if Docker Compose started correctly
if ! sudo docker-compose ps | grep "Up"; then
  echo "Docker containers failed to start. Check logs with 'docker-compose logs'."
  exit 1
fi

# Output final message
echo "Deployment complete. Your Superset app and PostgreSQL database are now running."
