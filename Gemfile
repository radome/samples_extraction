source 'https://rubygems.org'

gem 'rdf-n3'
gem 'tzinfo-data'
gem 'puma'
gem 'ejs'
gem 'dropzonejs-rails'
gem 'rest-client'
gem 'rails-assets-tether', '>= 1.1.0'
gem 'bootstrap_form'
gem 'sprockets-rails'
gem 'ace-rails-ap'
gem 'daemons'
gem 'yajl-ruby', '>= 1.3'


gem 'activerecord-session_store'

gem 'js_cookie_rails'


gem 'micro_token'

gem 'barby'


gem 'delayed_job'
gem 'delayed_job_active_record'

gem 'sequencescape-client-api',
  # Should be switched back to sanger + production for deployment
  :github => 'emrojo/sequencescape-client-api',
  :branch  => 'asset-attribute-update-merged-with-rails-4',
  :require => 'sequencescape'


# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails'
# Use mysql as the database for Active Record
gem 'mysql2', '>= 0.3.13', '< 0.5'
#gem 'sqlite3'
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
gem 'bootstrap-sass'
gem 'will_paginate'
gem 'will_paginate-bootstrap'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
gem 'therubyracer'

# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Unicorn as the app server
# gem 'unicorn'

# Add simple support for print-my barcode)
gem 'pmb-client', '0.1.0', :github => 'sanger/pmb-client'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

group :development, :test, :selenium do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
  gem 'factory_girl_rails'
  gem 'pry'
  gem 'ruby-growl'
end

group :debug do
  gem 'bullet'
  gem 'brakeman'
  gem 'deadweight'
  gem 'rack-mini-profiler', require: false
  # For memory profiling (requires Ruby MRI 2.1+)
  gem 'memory_profiler'

  # For call-stack profiling flamegraphs (requires Ruby MRI 2.0.0+)
  gem 'flamegraph'
  gem 'stackprof'     # For Ruby MRI 2.1+
  gem 'fast_stack'    # For Ruby MRI 2.0

  gem 'traceroute'
  gem 'peek'
  gem 'peek-mysql2'
  gem 'peek-gc'
  gem 'peek-performance_bar'
  gem 'rails_panel'
  gem 'rubocop'
  gem 'rubycritic'

end

group :test, :selenium do
  gem 'shoulda'
  gem 'factory_girl'
  gem 'rspec-rails'
  gem 'shoulda-matchers'
  gem 'rails-controller-testing'
  #gem 'cucumber-rails', :require => false
  gem 'database_cleaner'
end

group :selenium do
  gem 'selenium-webdriver'
end

group :test do
  gem 'poltergeist'
  gem 'launchy'
  gem 'rack_session_access'
end


group :development do
  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  gem 'rubocop', require: false
end


group :deployment do
  gem "psd_logger",
    :github => "sanger/psd_logger"
  gem "gmetric", "~>0.1.3"
  gem "exception_notification"
end
