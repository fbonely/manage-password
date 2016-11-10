#!/usr/bin/ruby

require 'mpw/config'
require 'test/unit'
require 'locale'
require 'i18n'

class TestConfig < Test::Unit::TestCase
	def setup
		lang = Locale::Tag.parse(ENV['LANG']).to_simple.to_s[0..1]
		
		if defined?(I18n.enforce_available_locales)
			I18n.enforce_available_locales = true
		end
		
		I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
		I18n.load_path      = Dir["#{File.expand_path('../../i18n', __FILE__)}/*.yml"]
		I18n.default_locale = :en
		I18n.locale         = lang.to_sym
	end

	def test_00_config
		data = { key: 'test@example.com',
		         lang: 'en',
		         wallet_dir: '/tmp/test',
		         gpg_exe: '',
		       }

		@config = MPW::Config.new
		@config.setup(data[:key], data[:lang], data[:wallet_dir], data[:gpg_exe])
		@config.load_config

		data.each do |k,v|
			assert_equal(v, @config.send(k))
		end

		@config.setup_gpg_key('password', 'test@example.com', 2048)
		assert(@config.check_gpg_key?)
	end
end
