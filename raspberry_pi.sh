# raspberry pi os imager - debian 11 bullseye based
#    - raspberry pi 3 b+ is 64-bit (d'oh!)

sudo apt update
sudo apt full-upgrade

# postgresql 14 - https://computingforgeeks.com/how-to-install-postgresql-14-on-debian/
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -

#redis - https://redis.io/docs/getting-started/installation/install-redis-on-linux/
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

sudo apt -y update

sudo apt install -y \
     git \
     gnupg2 \
     libpq-dev \
     mg \
     postgresql-14 \
     redis \
     tmux \
     wget

git clone -o michaeljb https://github.com/michaeljb/18xx.games.git 18xx
cd 18xx
git checkout 1868WY-pi


# set up postgres role for user 'pi'
sudo su postgres
createuser pi -P --interactive  # enter password, yes superuser
psql -c 'CREATE DATABASE pi;'
exit  # to return to user 'pi'

# install stable rvm - https://rvm.io/rvm/install
# https://rvm.io/rvm/security
gpg --keyserver .... # <copy-paste gpg command from URL in comment, might need to try different key servers shown on the rvm security page
\curl -sSL https://get.rvm.io | bash -s stable

source /home/pi/.rvm/scripts/rvm

# install ruby (takes a while to compile)
rvm install 3.1.2

# update platform in Gemfile.lock to aarch64-linux (in PLATFORMS section and
# next to libv8-node)
bundle config build.pg --with-pg-config=/usr/bin/pg_config
bundle install

# install esbuild - similar to command in Dockerfile
curl -s https://registry.npmjs.org/esbuild-linux-arm64/-/esbuild-linux-arm64-0.14.36.tgz | tar xz
sudo mv package/bin/esbuild /usr/local/bin && rm -rf package

## I think this stuff wasn't actually needed...
# # add /usr/lib/postgresql/14/bin to PATH in .bashrc
# echo 'export PATH="$PATH:/usr/lib/postgresql/14/bin"' >> ~/.bashrc
# # fix locales for postgres
# sudo localedef -i en_US -f UTF-8 en_US.UTF-8
# # create data dir w/ correct permissions
# mkdir db/data
# chmod 0700 db/data
# initdb -D db/data --locale=en_US.UTF-8 -U=pi

psql -c 'CREATE DATABASE "18xx_development";'


# redis config
redis-server


export DATABASE_URL="postgres://pi:password@0.0.0.0:5432/18xx_development"
bundle exec rake dev_up
bundle exec unicorn -c config/unicorn.rb
