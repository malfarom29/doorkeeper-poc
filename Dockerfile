FROM ruby:2.6.5-slim

ARG DOCKER_UID=1000
ARG DOCKER_GID=1000
ARG DOCKER_GROUP=rails
ARG DOCKER_USER=rails
ARG STAGE=development
ARG HOME_DIR=/home/$DOCKER_USER
ARG GEM_DIR=$HOME_DIR/.gem
ARG BUNDLE_DIR=$GEM_DIR/bundle
ARG APP_DIR=/workspace

ENV APP_HOME=$APP_DIR
ENV HOME=$HOME_DIR
ENV GEM_HOME=$GEM_DIR
ENV PATH=$PATH:$BUNDLE_DIR/bin
ENV BUNDLE_PATH=$BUNDLE_DIR

# Update and install Linux dependencies
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y --no-install-recommends postgresql-client nano netcat libpq-dev gcc make dpkg-dev git

# Add user for Rails
RUN groupadd $DOCKER_GROUP -g $DOCKER_GID && useradd -m $DOCKER_USER -G sudo -g $DOCKER_GID -u $DOCKER_UID

# Create the main folders
RUN mkdir -p $HOME $GEM_HOME $BUNDLE_PATH $APP_HOME $APP_HOME/tmp/sockets $APP_HOME/tmp/pids $APP_HOME/storage $APP_HOME/postgres

# Change Home permssions
RUN chown -R $DOCKER_USER $HOME

# Sets the dafault user
USER $DOCKER_USER

# Copy project files
COPY . $APP_HOME
COPY ./docker/.gemrc $HOME
COPY ./docker $APP_HOME

# Sets the dafault working directory
WORKDIR $APP_HOME

# Install gems
RUN gem install bundler
RUN bundle install --jobs=4

# Clean up
# RUN rm -rf $BUNDLE_PATH/cache/*.gem \
#     && find $BUNDLE_PATH/gems/ -name "*.c" -delete \
#     && find $BUNDLE_PATH/gems/ -name "*.o" -delete

CMD ["./docker/web-entrypoint.sh"]