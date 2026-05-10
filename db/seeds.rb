require_relative "seeds/support/master_data_importer"
require_relative "seeds/support/external_sample_file_storage"

puts "Seeding from CSV..."
SeedSupport::MasterDataImporter.new.run
puts "Seed complete."
