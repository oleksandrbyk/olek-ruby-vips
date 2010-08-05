module Spec
  module Path
    def root
      @root ||= Pathname.new(File.expand_path('../../..', __FILE__))
    end

    def tmp(*path)
      root.join 'tmp', *path
    end

    def sample(*path)
      root.join 'spec', 'samples', *path
    end

    extend self
  end
end

