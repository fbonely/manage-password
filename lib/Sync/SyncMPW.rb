#!/usr/bin/ruby
# author: nishiki

require 'rubygems'
require 'i18n'
require 'socket'
require 'json'
require 'timeout'
	
module MPW
	class SyncMPW
	
		attr_accessor :error_msg
		attr_accessor :enable
	
		# Constructor
		# @args: host -> the server host
		#        port -> ther connection port
		#        gpg_key -> the gpg key
		#        password -> the remote password
		#        suffix -> the suffix file
		def initialize(host, user, password, suffix, port=nil)
			@error_msg = nil
			@enable    = false

			@host     = host
			@port     = !port.instance_of?(Integer) ? 2201 : port
			@gpg_key  = user
			@password = password
			@suffix   = suffix
		end
	
		# Connect to server
		# @rtrn: false if the connection fail
		def connect
			Timeout.timeout(10) do
				begin
					TCPSocket.open(@host, @port) do 
						@enable = true
					end
                rescue Errno::ENETUNREACH
						retry
				end
			end
		rescue Timeout::Error
			@error_msg = "#{I18n.t('error.timeout')}\n#{e}"
			@enable    = false
		rescue Exception => e
			@error_msg = "#{I18n.t('error.sync.connection')}\n#{e}"
			@enable    = false
		else
			return @enable
		end
	
		# Get data on server
		# @args: gpg_password -> the gpg password
		# @rtrn: nil if nothing data or error
		def get(file_tmp)
			return false if not @enable
		
			msg = nil
			TCPSocket.open(@host, @port) do |socket|
				send_msg = {action:  'get',
				            gpg_key:  @gpg_key,
				            password: @password,
				            suffix:   @suffix
				           }
				
				socket.puts send_msg.to_json
				msg = JSON.parse(socket.gets)
			end
			
			if not defined?(msg['error'])
				@error_msg = I18n.t('error.sync.communication')
				return false
			elsif not msg['error'].nil?
				@error_msg = I18n.t(msg['error'])
				return false
			end

			File.open(file_tmp, 'w') do |file|
				file << msg['data']
			end

			return true
		rescue Exception => e
			@error_msg = "#{I18n.t('error.sync.download')}\n#{e}"
			return false
		end
	
		# Update the remote data
		# @args: data -> the data to send on server
		# @rtrn: false if there is a problem
		def update(file_gpg)
			return true if not @enable
	
			data = File.open(file_gpg, 'r').read

			msg = nil
			TCPSocket.open(@host, @port) do |socket|
				send_msg = {action:   'update',
				            gpg_key:  @gpg_key,
				            password: @password,
				            suffix:   @suffix,
				            data:     data
				           }
				
				socket.puts send_msg.to_json
				msg = JSON.parse(socket.gets)
			end
	
			if not defined?(msg['error'])
				@error_msg = I18n.t('error.sync.communication')
				return false
			elsif msg['error'].nil?
				return true
			else
				@error_msg = I18n.t(msg['error'])
				return false
			end
		end
	
	end
end
