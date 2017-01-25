#!/usr/bin/ruby

require 'uri'
require 'yaml'
require 'resolv'
require 'optparse'
require 'net/http'
require 'net/https'


class TrafficNoise

        def initialize()
                @options = {}

                OptionParser.new do |opt|
                        opt.on('--config CONFIG') { |o| @options[:config] = o }
                end.parse!      

                begin
                        raise OptionParser::MissingArgument if @options[:config].nil?
                rescue
                        puts "Usage: -c config file "
                        exit    
                end
        end



        def raw_http(url, is_ssl)

                uri = URI.parse(url)
                http = Net::HTTP.new(uri.host, uri.port)
        
                http.open_timeout = 3 
                http.read_timeout = 3 

                if is_ssl
                        http.use_ssl = true
                        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                else
                        http.use_ssl = false
                end

                return http, uri        
        end
        
        
        def http_get(sleep_time, url, user_agent, is_ssl)
                
                while true
                        http, uri = raw_http(url, is_ssl)

                        headers = {'Content-Type'=> 'application/x-www-form-urlencoded', 'User-Agent' => user_agent}
                        request = Net::HTTP::Get.new(uri.request_uri, headers)
        
                        response = http.request(request)

                        sleep(sleep_time.to_int)
                end
        end


        def http_post(sleep_time, url, data, user_agent, is_ssl)

                while true
                        http, uri = raw_http(url, is_ssl)

                        request = Net::HTTP::Post.new(uri.request_uri)

                        headers = {'Content-Type'=> 'application/x-www-form-urlencoded', 'User-Agent' => user_agent}
                        response = http.post(url, data, headers)

                        sleep(sleep_time.to_int)

                end
        end
        
        
        def do_dns(domain, dns_server, a_records, type)

                dns = Resolv::DNS.new(:nameserver => ["#{dns_server}"], :ndots => 1)
                dns.timeouts = 3

                if type == "A"
                        a_records.split(",").each do |_record|
                                record = _record.strip()
                                domain_record = "#{record}.#{domain}"

                                dns.getresources(domain_record, Resolv::DNS::Resource::IN::A).collect do |r| 
                                end
                        end
                elsif type == "MX"
                        dns.getresources(domain, Resolv::DNS::Resource::IN::MX).collect do |r| 
                        end
                elsif type == "NS"
                        dns.getresources(domain, Resolv::DNS::Resource::IN::NS).collect do |r| 
                        end
                elsif type == "TXT"
                        dns.getresources(domain, Resolv::DNS::Resource::IN::TXT).collect do |r| 
                        end
                end
        end


        def dns(options)
                dns_server = options["dst_ip"]          
                sleep_time = options["sleep_time"]

                options["zone"].each do |zone|
                        domain = zone["domain"]
                        a_records = zone["aaa_data"]
                        
                        while true
        
                                operations = zone["operation"].split(",").each do |operation|
                                        do_dns(domain, dns_server, a_records, operation)
                                end                     
                                
                                sleep(sleep_time.to_int)
                        end
                end
        end
        
        
        def http(options, is_ssl)

                thread_array = []
                
                src_ip = options["src_ip"]
                user_agent = options["user_agent"]

                options["domain"].each do |val|

                        port = val["port"]
                        domain = val["name"]
                        sleep_time = val["sleep_time"]


                        get_values = val["get"]
                        post_values = val["post"]

                        get_values.each do |get|
                                url = get["url"]

                                full_url = "http://#{domain}:#{port}#{url}"
                                http_thread = Thread.new { http_get(sleep_time, full_url, user_agent, is_ssl) }
                                thread_array.push(http_thread)
                        end
        
                        post_values.each do |post|
                                url = post["url"]                       
                                data = post["data"]

                                full_url = "http://#{domain}:#{port}#{url}"
                                
                                http_thread = http_post(sleep_time, full_url, data, user_agent, is_ssl)
                                thread_array.push(http_thread)
                        end

                end

                thread_array.each { |thread| thread.join }
        end
        
        
        def run()
                config_file = @options[:config]
                config_values = YAML.load_file(config_file)

                thread_array = []

                config_values["protocol"].each do |proto_name, proto_val|
                        if proto_name == "http"
                                http_thread = Thread.start { http(proto_val, false) }
                                thread_array.push(http_thread)
                        elsif proto_name == "https"
                                https_thread = Thread.new { http(proto_val, true) }
                                thread_array.push(https_thread)
                        elsif proto_name == "dns"
                                dns_thread = Thread.start{ dns(proto_val) }
                                thread_array.push(dns_thread)
                        end

                end

                thread_array.each { |thread| thread.join }
        end
end


if __FILE__ == $0
        traffic_noiser = TrafficNoise.new
        traffic_noiser.run
end
