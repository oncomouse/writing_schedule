module ZipSource
	class << self
		def registered(app)
			app.after_build do |builder|
				builder.in_root do
					builder.run "zip -qr build/source.zip source/*"
				end
			end
		end
	
		alias :included :registered
	end
end

::Middleman::Extensions.register(:zip_source, ZipSource)