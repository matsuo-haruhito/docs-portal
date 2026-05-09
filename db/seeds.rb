require_relative "seeds/support/master_data_importer"

puts "Seeding from CSV..."
SeedSupport::MasterDataImporter.new.run
puts "Seed complete."
