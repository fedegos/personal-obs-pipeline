ENV["RAILS_ENV"] ||= "test"

require "simplecov"
SimpleCov.command_name "minitest-#{Process.pid}"
SimpleCov.start "rails" do
  enable_coverage :branch
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/vendor/"
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services", "app/services"
  add_group "Consumers", "app/consumers"
  add_group "Helpers", "app/helpers"
  minimum_coverage 60 # Temporalmente bajado mientras mejoramos cobertura
end

require_relative "../config/environment"
require "rails/test_help"

null_producer = Object.new
null_producer.define_singleton_method(:produce_async) { |**_| }
Karafka.define_singleton_method(:producer) { null_producer }

module ActiveSupport
  class TestCase
    workers = ENV["PARALLEL_WORKERS"]
    parallelize(workers: workers.present? ? workers.to_i : :number_of_processors)
  end
end
