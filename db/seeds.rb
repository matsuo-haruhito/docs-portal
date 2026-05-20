require_relative "seeds/support/master_data_importer"
require_relative "seeds/support/external_sample_file_storage"
require_relative "seeds/support/seed_sample_document_generator"

puts "Preparing seed sample documents..."
SeedSupport::SeedSampleDocumentGenerator.new.run
puts "Seeding from CSV..."
SeedSupport::MasterDataImporter.new.run
puts "Seed complete."