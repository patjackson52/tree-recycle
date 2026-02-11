web: bundle exec puma -C config/puma.rb
# Release phase runs before a new release completes. Use it to run DB migrations.
release: bundle exec rails db:migrate
worker: rake jobs:work