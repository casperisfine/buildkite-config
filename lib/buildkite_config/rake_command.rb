require "buildkite-builder"

module Buildkite::Config
  class RakeCommand < Buildkite::Builder::Extension
    dsl do
      def to_label(ruby, dir, task = "")
        str = +"#{dir} #{task.sub(/[:_]test|test:/, "")}"
        str.sub!(/ test/, "")
        return str unless ruby.version

        str << " (#{ruby.short_ruby})"
      end

      def rake(dir = "", task = "", service: "default", pre_steps:[], &block)
        build_context = context.extensions.find(BuildContext)

        ## Setup ENV
        _env = {
          IMAGE_NAME: build_context.ruby.image_name_for(build_context.build_id)
        }

        if build_context.ruby.yjit_enabled?
          _env[:RUBY_YJIT_ENABLE] = "1"
        end

        if !(pre_steps).empty?
          _env[:PRE_STEPS] = pre_steps.join(" && ")
        end

        _label = to_label(build_context.ruby, dir, task)

        command do
          label _label
          depends_on "docker-image-#{build_context.ruby.image_name}"
          command "rake #{task}"

          plugin build_context.artifacts_plugin, {
            download: %w[.buildkite/* .buildkite/**/*]
          }

          plugin build_context.docker_compose_plugin,{
            "env" => [
              "PRE_STEPS",
              "RACK"
            ],
            "run" => service,
            "pull" => service,
            "config" => ".buildkite/docker-compose.yml",
            "shell" => ["runner", dir],
          }

          env _env
          agents queue: build_context.run_queue
          artifact_paths build_context.artifact_paths
          automatic_retry_on(**build_context.automatic_retry_on)
          timeout_in_minutes build_context.timeout_in_minutes

          instance_exec([@attributes, build_context], &block) if block_given?
        end
      end
    end
  end
end
