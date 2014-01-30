#!/usr/bin/ruby
# author: nishiki
# mail: nishiki@yaegashi.fr
# info: a simple script who manage your passwords

module MPW

	require 'rubygems'
	require 'yaml'
	require 'i18n'
	
	class Config
		
		attr_accessor :error_msg
	
		attr_accessor :key
		attr_accessor :lang
		attr_accessor :file_gpg
		attr_accessor :timeout_pwd
		attr_accessor :last_update
		attr_accessor :sync_type
		attr_accessor :sync_host
		attr_accessor :sync_port
		attr_accessor :sync_user
		attr_accessor :sync_pwd
		attr_accessor :sync_path
		attr_accessor :last_update
	
		# Constructor
		# @args: file_config -> the specify config file
		def initialize(file_config=nil)
			@error_msg   = nil
			@file_config = "#{Dir.home()}/.mpw.cfg"
	
			if !file_config.nil? && !file_config.empty?
				@file_config = file_config
			end
		end
	
		# Create a new config file
		# @args: key -> the gpg key to encrypt
		#        lang -> the software language
		#        file_gpg -> the file who is encrypted
		#        timeout_pwd -> time to save the password
		#        sync_type -> the type to synchronization
		#        sync_host -> the server host for synchronization
		#        sync_port -> the server port for synchronization
		#        sync_user -> the user for synchronization
		#        sync_pwd -> the password for synchronization
		#        sync_suffix -> the suffix file (optionnal) 
		# @rtrn: true if le config file is create
		def setup(key, lang, file_gpg, timeout_pwd, sync_type=nil, sync_host=nil, sync_port=nil, sync_user=nil, sync_pwd=nil, sync_path=nil)
	
			if not key =~ /[a-zA-Z0-9.-_]+\@[a-zA-Z0-9]+\.[a-zA-Z]+/
				@error_msg = I18n.t('error.config.key_bad_format')
				return false
			end
			
			if file_gpg.empty?
				file_gpg = "#{Dir.home()}/.mpw.gpg"
			end
	
			timeout_pwd = timeout_pwd.empty? ? 60 : timeout_pwd.to_i
	
			config = {'config' => {'key'         => key,
			                       'lang'        => lang,
			                       'file_gpg'    => file_gpg,
			                       'timeout_pwd' => timeout_pwd,
			                       'sync_type'   => sync_type,
			                       'sync_host'   => sync_host,
			                       'sync_port'   => sync_port,
			                       'sync_user'   => sync_user,
			                       'sync_pwd'    => sync_pwd,
			                       'sync_path'   => sync_path,
			                       'last_update' => 0 }}
	
			File.open(@file_config, 'w') do |file|
				file << config.to_yaml
			end
			
			return true
		rescue Exception => e 
			@error_msg = "#{I18n.t('error.config.write')}\n#{e}"
			return false
		end
	
		# Check the config file
		# @rtrn: true if the config file is correct
		def checkconfig()
			config = YAML::load_file(@file_config)
			@key         = config['config']['key']
			@lang        = config['config']['lang']
			@file_gpg    = config['config']['file_gpg']
			@timeout_pwd = config['config']['timeout_pwd'].to_i
			@sync_type   = config['config']['sync_type']
			@sync_host   = config['config']['sync_host']
			@sync_port   = config['config']['sync_port']
			@sync_user   = config['config']['sync_user']
			@sync_pwd    = config['config']['sync_pwd']
			@sync_path   = config['config']['sync_path']
			@last_update = config['config']['last_update'].to_i

			if @key.empty? || @file_gpg.empty? 
				@error_msg = I18n.t('error.config.check')
				return false
			end

			I18n.locale = @lang.to_sym

			return true
		rescue Exception => e 
			@error_msg = "#{I18n.t('error.config.check')}\n#{e}"
			return false
		end
	
		# Set the last update when there is a sync
		# @rtrn: true is the file has been updated
		def set_last_update
			config = {'config' => {'key'         => @key,
			                       'lang'        => @lang,
			                       'file_gpg'    => @file_gpg,
			                       'timeout_pwd' => @timeout_pwd,
			                       'sync_type'   => @sync_type,
			                       'sync_host'   => @sync_host,
			                       'sync_port'   => @sync_port,
			                       'sync_user'   => @sync_user,
			                       'sync_pwd'    => @sync_pwd,
			                       'sync_path'   => @sync_path,
			                       'last_update' => Time.now.to_i }}
	
			File.open(@file_config, 'w') do |file|
				file << config.to_yaml
			end

			return true
		rescue Exception => e 
			@error_msg = "#{I18n.t('error.config.write')}\n#{e}"
			return false
		end
		
	end

end
