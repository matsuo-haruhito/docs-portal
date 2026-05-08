module ApplicationConfiguration
  class CheckBuilder
    def initialize(check_class:)
      @check_class = check_class
    end

    def ok(key, label, message, detail = nil)
      check_class.new(key:, label:, status: :ok, message:, detail:)
    end

    def warning(key, label, message, detail = nil)
      check_class.new(key:, label:, status: :warning, message:, detail:)
    end

    def error(key, label, message, detail = nil)
      check_class.new(key:, label:, status: :error, message:, detail:)
    end

    private

    attr_reader :check_class
  end
end
