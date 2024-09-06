#!/usr/bin/env ruby

require 'vaas'  
require 'digest'
require 'fileutils'
require 'json'

POSTFIX_DIR = '/var/spool/postfix/incoming/'
LOG_FILE = '/var/log/vaas_scan.log'
STATE_FILE = '/var/log/vaas_scan_state.json'
API_KEY = 'your_vaas_api_key'  

def load_scan_state
  return {} unless File.exist?(STATE_FILE)
  JSON.parse(File.read(STATE_FILE))
end

def save_scan_state(state)
  File.write(STATE_FILE, state.to_json)
end

def scan_file(file_path)
  client = Vaas::Client.new(api_key: API_KEY)
  
  begin
    response = client.scan_file(file_path)
    verdict = response.malicious? ? 'Malicious' : 'Clean'
    log_scan_result(file_path, verdict)
    verdict
  rescue StandardError => e
    puts "Error scanning file: #{file_path}, #{e.message}"
    log_scan_result(file_path, "Error: #{e.message}")
    "Error"
  end
end

def log_scan_result(file_path, verdict)
  size = File.size(file_path)
  timestamp = File.mtime(file_path).strftime("%Y-%m-%d %H:%M:%S")
  log_entry = "#{timestamp} | File: #{file_path} | Size: #{size} bytes | Verdict: #{verdict}\n"
  File.open(LOG_FILE, 'a') { |f| f.write(log_entry) }
end

def scan_directory
  scan_state = load_scan_state
  new_scan_state = {}

  Dir.glob("#{POSTFIX_DIR}*").each do |file|
    next unless File.file?(file)

    file_size = File.size(file)
    file_mtime = File.mtime(file).to_i

    if !scan_state[file] || scan_state[file]['size'] != file_size
      verdict = scan_file(file)
      puts "#{file} -> #{verdict}"
    end

    new_scan_state[file] = { 'size' => file_size, 'mtime' => file_mtime }
  end

  save_scan_state(new_scan_state)
end

scan_directory

