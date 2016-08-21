require 'httparty'
require_relative 'rule'

class Dsl
	include HTTParty
	follow_redirects false
	MAX_REDIRECTS = 3

	CODES_TO_OBJ = ::Net::HTTPResponse::CODE_CLASS_TO_OBJ.merge ::Net::HTTPResponse::CODE_TO_OBJ
    attr_accessor :id, :rules

    def initialize(id, &block)
      @id = id
	  @rules = []
	  instance_eval &block
	end

	def get(url, options = {})
		request('GET', url, options)
	end

	def post(url, options = {})
		request('POST', url, options)
	end

	def follow_redirects(url)
		redirects_count = 0
		input_url = url
		result = []
		loop do
			response = self.class.get(input_url)
			result << { url: input_url, status: response.code.to_s, redirects: redirects_count}
			#puts "****** url: #{input_url}, status code: #{response.code.to_s} (#{CODES_TO_OBJ[response.code.to_s]})"
			input_url =	response.header['location']
			redirects_count +=1
			break unless input_url || redirects_count > MAX_REDIRECTS
		end
		return result
	end

	def get_response_respond_with(data)
		data.last[:url]
	end

	def get_response_redirects_count(data)
		data.last[:redirects]
	end

	def validate_redirects(data, redirect_code)
		data.each do |url_data|
			return false if url_data[:status] != redirect_code.to_s
		end
		true
	end

	def request(method, url, options = {})
		puts "*"
		rule = Rule.new(url, options)
		rules << rule
		result_ok = true
		begin
			case method
			when 'GET'
				results = follow_redirects(rule.url)
				respond_url = get_response_respond_with(results)
				result_ok &&= rule.redirect_url == respond_url if rule.redirect_url
				result_ok &&= validate_redirects(results[0..(results.size-2)], rule.response_code) if rule.response_code
				#puts "RESULT: #{result_ok} for #{rule.url}, redirects: #{get_response_redirects_count(results)}"
			when 'POST'
				response_result = self.class.post(rule.url)
				result_ok &&= rule.redirect_url == response_result.code if rule.redirect_url
			else
			end

		rescue HTTParty::Error => e
	    	error = 'HttParty::Error '+ e.message
	    	rule.error_message(error)
		rescue StandardError => e
			error = 'StandardError '+ e.message
			rule.error_message(error)
		else
			rule.error_message = "Condition doesn't match" if false == result_ok
		end
	end

	def display_results
		puts "Tests done: #{rules.length}"
		if rules.any?
			puts "Errors: \n"
			rules.each{|e| puts "#{e.to_s}"}
		end
	end
end