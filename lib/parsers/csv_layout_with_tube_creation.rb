module Parsers
  class CsvLayoutWithTubeCreation < Parsers::CsvLayout
    def create_tubes?
      true
    end
  end
end
