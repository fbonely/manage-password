#!/usr/bin/ruby
# author: nishiki
# mail: nishiki@yaegashi.fr
# info: a simple script who manage your passwords

require 'rubygems'
require 'gpgme'
require 'csv'
require 'yaml'
require 'i18n'

class MPW
	
	ID       = 0
	NAME     = 1
	GROUP    = 2
	PROTOCOL = 3
	SERVER   = 4
	LOGIN    = 5
	PASSWORD = 6
	PORT     = 7
	COMMENT  = 8

	attr_accessor :error_msg
	attr_accessor :timeout_pwd

	# Constructor
	# @args: file_config -> the specify config file
	def initialize(file_config=nil)
		@error_msg  = nil
		@file_config = "#{Dir.home()}/.mpw.cfg"

		if !file_config.nil? && !file_config.empty?
			@file_config = file_config
		end
	end

	# Create a new config file
	# @args: key -> the gpg key to encrypt
	#        lang -> the software language
	#        file_gpg -> the file who is encrypted
	#        file_pwd -> the file who stock the password
	#        timeout_pwd -> time to save the password 
	# @rtrn: true if le config file is create
	def setup(key, lang, file_gpg, timeout_pwd)

		if not key =~ /[a-zA-Z0-9.-_]+\@[a-zA-Z0-9]+\.[a-zA-Z]+/
			@error_msg = I18n.t('error.config.key_bad_format')
			return false
		end
		
		if file_gpg.empty?
			file_gpg = "#{Dir.home()}/.mpw.gpg"
		end

		timeout_pwd.empty? ? (timeout_pwd = 60) : (timeout_pwd = timeout_pwd.to_i)

		config = {'config' => {'key'         => key,
		                       'lang'        => lang,
		                       'file_gpg'    => file_gpg,
		                       'timeout_pwd' => timeout_pwd}}

		begin
			File.open(@file_config, 'w') do |file|
				file << config.to_yaml
			end
		rescue Exception => e 
			@error_msg = "#{I18n.t('error.config.write')}\n#{e}"
			return false
		end

		return true
	end

	# Check the config file
	# @rtrn: true if the config file is correct
	def checkconfig()
		begin
			config = YAML::load_file(@file_config)
			@key         = config['config']['key']
			@lang        = config['config']['lang']
			@file_gpg    = config['config']['file_gpg']
			@timeout_pwd = config['config']['timeout_pwd'].to_i

			if @key.empty? || @file_gpg.empty? 
				@error_msg = I18n.t('error.config.check')
				return false
			end
				
			I18n.locale = @lang.to_sym

		rescue Exception => e 
			@error_msg = "#{I18n.t('error.config.check')}\n#{e}"
			return false
		end

		return true
	end

	# Decrypt a gpg file
	# @args: password -> the GPG key password
	# @rtrn: true if data has been decrypted
	def decrypt(passwd=nil)
		@data = Array.new

		begin
			if File.exist?(@file_gpg)
				crypto = GPGME::Crypto.new(:armor => true)
				data_decrypt = crypto.decrypt(IO.read(@file_gpg), :password => passwd).read

				id = 0
				data_decrypt.lines do |line|
					@data[id] = line.parse_csv.unshift(id)
					id += 1;
				end
			end

			return true
		rescue Exception => e 
			if !@file_pwd.nil? && File.exist?(@file_pwd)
				File.delete(@file_pwd)
			end
			
			@error_msg = "#{I18n.t('error.gpg_file.decrypt')}\n#{e}"
			return false
		end
	end

	# Encrypt a file
	# @rtrn: true if the file has been encrypted
	def encrypt()
		begin
			crypto = GPGME::Crypto.new(:armor => true)
			file_gpg = File.open(@file_gpg, 'w+')

			data_to_encrypt = ''
			@data.each do |row|
				data_to_encrypt << row.drop(1).to_csv
			end

			crypto.encrypt(data_to_encrypt, :recipients => @key, :output => file_gpg)
			file_gpg.close

			return true
		rescue Exception => e 
			@error_msg = "#{I18n.t('error.gpg_file.encrypt')}\n#{e}"
			return false
		end
	end
	
	# Search in some csv data
	# @args: search -> the string to search
	#        protocol -> the connection protocol (ssh, web, other)
	# @rtrn: a list with the resultat of the search
	def search(search, group=nil, protocol=nil)
		result = Array.new()

		if !search.nil?
			search = search.downcase
		end
		search = search.force_encoding('ASCII-8BIT')

		@data.each do |row|
			row[NAME].nil?    ? (name    = nil) : (name    = row[NAME].downcase)
			row[SERVER].nil?  ? (server  = nil) : (server  = row[SERVER].downcase)
			row[COMMENT].nil? ? (comment = nil) : (comment = row[COMMENT].downcase)

			if name =~ /^.*#{search}.*$/  || server =~ /^.*#{search}.*$/ || comment =~ /^.*#{search}.*$/ 
				if (protocol.nil? || protocol.eql?(row[PROTOCOL])) && (group.nil? || group.eql?(row[GROUP]))
					result.push(row)
				end
			end
		end

		return result
	end

	# Search in some csv data
	# @args: id -> the id item
	# @rtrn: a row with the resultat of the search
	def searchById(id)
		if not @data[id.to_i].nil?
			return @data[id.to_i]
		else
			return Array.new
		end
	end

	# Add a new item
	# @args: name -> the item name
	#        group -> the item group
	#        server -> the ip or server
	#        protocol -> the protocol
	#        login -> the login
	#        passwd -> the password
	#        port -> the port
	#        comment -> a comment
	# @rtrn: true if it works
	def add(name, group=nil, server=nil, protocol=nil, login=nil, passwd=nil, port=nil, comment=nil)
		row = Array.new()
		
		if name.nil? || name.empty?
			@error_msg = I18n.t('error.add.name_empty')
			return false
		end
		
		if port.to_i <= 0
			port = nil
		end

		if not @data.last.nil?
			id = @data.last
			id = id[ID].to_i + 1
		else
			id = 0
		end

		row[ID]    = id
		row[PORT]  = port
		row[NAME]  = name.force_encoding('ASCII-8BIT')
		group.nil?    || group.empty?    ? (row[GROUP]    = nil) : (row[GROUP]    = group.force_encoding('ASCII-8BIT'))
		server.nil?   || server.empty?   ? (row[SERVER]   = nil) : (row[SERVER]   = server.force_encoding('ASCII-8BIT'))
		protocol.nil? || protocol.empty? ? (row[PROTOCOL] = nil) : (row[PROTOCOL] = protocol.force_encoding('ASCII-8BIT'))
		login.nil?    || login.empty?    ? (row[LOGIN]    = nil) : (row[LOGIN]    = login.force_encoding('ASCII-8BIT'))
		passwd.nil?   || passwd.empty?   ? (row[PASSWORD] = nil) : (row[PASSWORD] = passwd.force_encoding('ASCII-8BIT'))
		comment.nil?  || comment.empty?  ? (row[COMMENT]  = nil) : (row[COMMENT]  = comment.force_encoding('ASCII-8BIT'))

		@data[id] = row

		return true
	end
	
	# Update an item
	# @args: id -> the item's identifiant
	#        name -> the item name
	#        group ->  the item group
	#        server -> the ip or hostname
	#        protocol -> the protocol
	#        login -> the login
	#        passwd -> the password
	#        port -> the port
	#        comment -> a comment
	# @rtrn: true if the item has been updated
	def update(id, name=nil, group=nil, server=nil, protocol=nil, login=nil, passwd=nil, port=nil, comment=nil)
		id = id.to_i

		if not @data[id].nil?

			if port.to_i <= 0
				port = nil
			end

			row = @data[id]
			row_update = Array.new()

			name.nil?     || name.empty?     ? (row_update[NAME]     = row[NAME])     : (row_update[NAME]     = name)
			group.nil?    || group.empty?    ? (row_update[GROUP]    = row[GROUP])    : (row_update[GROUP]    = group)
			server.nil?   || server.empty?   ? (row_update[SERVER]   = row[SERVER])   : (row_update[SERVER]   = server)
			protocol.nil? || protocol.empty? ? (row_update[PROTOCOL] = row[PROTOCOL]) : (row_update[PROTOCOL] = protocol)
			login.nil?    || login.empty?    ? (row_update[LOGIN]    = row[LOGIN])    : (row_update[LOGIN]    = login)
			passwd.nil?   || passwd.empty?   ? (row_update[PASSWORD] = row[PASSWORD]) : (row_update[PASSWORD] = passwd)
			port.nil?     || port.empty?     ? (row_update[PORT]     = row[PORT])     : (row_update[PORT]     = port)
			comment.nil?  || comment.empty?  ? (row_update[COMMENT]  = row[COMMENT])  : (row_update[COMMENT]  = comment)
			
			@data[id] = row_update

			return true
		else
			@error_msg = I18n.t('error.update.id_no_exist', :id => id)
			return false
		end
	end
	
	# Remove an item 
	# @args: id -> the item's identifiant
	# @rtrn: true if the item has been deleted
	def remove(id)
		if not @data.delete_at(id.to_i).nil?
			return true
		else
			@error_msg = I18n.t('error.delete.id_no_exist', :id => id)
			return false
		end
	end

	# Export to csv
	# @args: file -> a string to match
	# @rtrn: true if export work
	def export(file)
		begin
			File.open(file, 'w+') do |file|
				@data.each do |row|
					row.delete_at(ID)
					file << row.to_csv
				end
			end

			return true
		rescue Exception => e 
			@error_msg = "#{I18n.t('error.export.write', :file => file)}\n#{e}"
			return false
		end
	end

	# Import to csv
	# @args: file -> path to file import
	# @rtrn: true if the import work
	def import(file)
		begin
			data_new = IO.read(file)
			data_new.lines do |line|
				if not line =~ /(.*,){6}/
					@error_msg = I18n.t('error.import.bad_format')
					return false
				else
					row = line.parse_csv.unshift(0)
					if not add(row[NAME], row[GROUP], row[SERVER], row[PROTOCOL], row[LOGIN], row[PASSWORD], row[PORT], row[COMMENT])
						return false
					end
				end
			end

			return true
		rescue Exception => e 
			@error_msg = "#{I18n.t('error.import.read', :file => file)}\n#{e}"
			return false
		end
	end

	# Return 
	# @args: file -> path to file import
	# @rtrn: an array with the items to import, if there is an error return false
	def importPreview(file)
		begin
			result = Array.new()
			id = 0

			data = IO.read(file)
			data.lines do |line|
				if not line =~ /(.*,){6}/
					@error_msg = I18n.t('error.import.bad_format')
					return false
				else
					result.push(line.parse_csv.unshift(id))
				end

				id += 1
			end

			return result
		rescue Exception => e 
			@error_msg = "#{I18n.t('error.import.read', :file => file)}\n#{e}"
			return false
		end
	end

	# Generate a random password
	# @args: length -> the length password
	# @rtrn: a random string
	def self.generatePassword(length=8)
		if length.to_i <= 0
			length = 8
		end

		return ([*('A'..'Z'),*('a'..'z'),*('0'..'9')]).sample(length.to_i).join
		#return ([*('A'..'Z'),*('a'..'z'),*('0'..'9')]-%w(0 1 I O l i o)).sample(length).join
	end
		
end
