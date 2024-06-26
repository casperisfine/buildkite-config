# frozen_string_literal: true

require "test_helper"
require "buildkite_config"

class TestDockerBuild < TestCase
  def test_builder_with_ruby_config_using_string_version
    pipeline = PipelineFixture.new do
      use Buildkite::Config::DockerBuild

      build_context.stub(:rails_version, Gem::Version.new("7.1")) do
        builder Buildkite::Config::RubyConfig.new(prefix: "builder:", version: "3.2")
      end
    end

    %w[label key env].each do |key|
      assert_includes pipeline.to_h["steps"][0], key
    end

    assert_equal ":docker: builder:3.2", pipeline.to_h["steps"][0]["label"]
    assert_equal "docker-image-builder-3-2", pipeline.to_h["steps"][0]["key"]
    assert_equal "builder:3.2", pipeline.to_h["steps"][0]["env"]["RUBY_IMAGE"]
  end

  def test_builder_artifacts
    pipeline = PipelineFixture.new do
      use Buildkite::Config::DockerBuild

      build_context.stub(:rails_version, Gem::Version.new("7.1")) do
        builder Buildkite::Config::RubyConfig.new(version: "3.2")
      end
    end

    assert_includes pipeline.to_h["steps"][0], "plugins"
    plugins = pipeline.to_h["steps"][0]["plugins"]

    artifacts = plugins.select { |plugin|
      plugin.key?("artifacts#v1.0")
    }
    assert_equal ".dockerignore", artifacts[0]["artifacts#v1.0"]["download"]

    download = artifacts[1]["artifacts#v1.0"]
    assert_equal %w[
      .buildkite/.empty
      .buildkite/docker-compose.yml
      .buildkite/Dockerfile
      .buildkite/Dockerfile.beanstalkd
      .buildkite/mysql-initdb.d
      .buildkite/runner
    ], download["download"]
    assert_equal ".buildkite.tgz", download["compressed"]
  end

  def test_builder_compose_plugin
    pipeline = PipelineFixture.new do
      use Buildkite::Config::DockerBuild

      build_context.stub(:rails_version, Gem::Version.new("7.1")) do
        builder Buildkite::Config::RubyConfig.new(version: "3.2")
      end
    end

    plugins = pipeline.to_h["steps"][0]["plugins"]

    compose = plugins.find { |plugin|
      plugin.key?("docker-compose#v1.0")
    }.fetch("docker-compose#v1.0")

    %w[image-name cache-from push build config env image-repository].each do |key|
      assert_includes compose, key
    end

    assert_equal "3-2-local", compose["image-name"]
    assert_equal ["base:buildkite-config-base:3-2-br-main"], compose["cache-from"]
    assert_equal ["base:buildkite-config-base:3-2-br-"], compose["push"]

    assert_equal "base", compose["build"]
    assert_equal ".buildkite/docker-compose.yml", compose["config"]
    assert_includes compose["env"], "PRE_STEPS"
    assert_includes compose["env"], "RACK"
    assert_equal "buildkite-config-base", compose["image-repository"]
  end

  def test_builder_timeout_default
    pipeline = PipelineFixture.new do
      use Buildkite::Config::DockerBuild

      build_context.stub(:rails_version, Gem::Version.new("7.1")) do
        builder Buildkite::Config::RubyConfig.new(version: "3.2")
      end
    end

    assert_includes pipeline.to_h["steps"][0], "timeout_in_minutes"
    assert_equal 15, pipeline.to_h["steps"][0]["timeout_in_minutes"]
  end

  def test_builder_agents_default
    pipeline = PipelineFixture.new do
      use Buildkite::Config::DockerBuild

      build_context.stub(:rails_version, Gem::Version.new("7.1")) do
        builder Buildkite::Config::RubyConfig.new(version: "3.2")
      end
    end

    assert_includes pipeline.to_h["steps"][0], "agents"
    assert_equal({ "queue" => "builder" }, pipeline.to_h["steps"][0]["agents"])
  end

  def test_builder_env_default
    pipeline = PipelineFixture.new do
      use Buildkite::Config::DockerBuild

      build_context.stub(:rails_version, Gem::Version.new("7.1")) do
        builder Buildkite::Config::RubyConfig.new(version: "3.2")
      end
    end
    assert_includes pipeline.to_h["steps"][0]["env"], "BUNDLER"
    assert_includes pipeline.to_h["steps"][0]["env"], "RUBYGEMS"
    assert_includes pipeline.to_h["steps"][0]["env"], "encrypted_0fb9444d0374_key"
    assert_includes pipeline.to_h["steps"][0]["env"], "encrypted_0fb9444d0374_iv"
  end

  def test_builder_skip
    pipeline = PipelineFixture.new do
      use Buildkite::Config::DockerBuild
      yjit = Buildkite::Config::RubyConfig.yjit_ruby

      build_context.stub(:rails_version, Gem::Version.new("7.1")) do
        builder yjit
      end
    end

    assert_equal({}, pipeline.to_h)
  end

  def test_builder_gem_version
    pipeline = PipelineFixture.new do
      use Buildkite::Config::DockerBuild

      build_context.stub(:rails_version, Gem::Version.new("7.1")) do
        builder Buildkite::Config::RubyConfig.new(prefix: "ruby:", version: Gem::Version.new("1.9.3"))
      end
    end

    plugins = pipeline.to_h["steps"][0]["plugins"]

    compose = plugins.find { |plugin|
      plugin.key?("docker-compose#v1.0")
    }.fetch("docker-compose#v1.0")

    assert_equal "ruby-1-9-3-local", compose["image-name"]
    assert_equal ["base:buildkite-config-base:ruby-1-9-3-br-main"], compose["cache-from"]
    assert_equal ["base:buildkite-config-base:ruby-1-9-3-br-"], compose["push"]
  end
end
