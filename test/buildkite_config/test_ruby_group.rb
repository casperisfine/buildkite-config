# frozen_string_literal: true

require "test_helper"
require "buildkite_config"

class TestRubyGroup < TestCase
  def test_ruby_group
    pipeline = PipelineFixture.new do
      use Buildkite::Config::RubyGroup

      ruby_group version: "3.2" do
        build_context = context.extensions.find(Buildkite::Config::BuildContext)

        command do
          label "test [#{build_context.ruby.version}]]}]"
          command "rake test"
        end
      end
    end

    expected = {"steps"=>
      [{"label"=>"3.2",
        "group"=>nil,
        "steps"=>[{"label"=>"test [3.2]]}]", "command"=>["rake test"]}]}]}
    assert_equal expected, pipeline.to_h
  end

  def test_soft_fail
    pipeline = PipelineFixture.new do
      use Buildkite::Config::RubyGroup

      ruby_group version: "3.2", soft_fail: true do
        build_context = context.extensions.find(Buildkite::Config::BuildContext)

        command do
          label "test [#{"soft_fail" if build_context.ruby.soft_fail?}]]}]"
          command "rake test"
        end
      end
    end

    expected = {"steps"=>
      [{"label"=>"3.2",
        "group"=>nil,
        "steps"=>[{"label"=>"test [soft_fail]]}]", "command"=>["rake test"]}]}]}
    assert_equal expected, pipeline.to_h
  end
end
