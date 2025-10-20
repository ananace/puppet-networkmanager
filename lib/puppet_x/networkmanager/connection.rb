# frozen_string_literal: true

require 'puppet/util/inifile'

module PuppetX # rubocop:disable Style/ClassAndModuleChildren
  module Networkmanager
    # Networkmanager connection wrapper
    #
    # To reduce to-file flushes
    class Connection
      def self.[](path)
        (@connections ||= {})[path] ||= new(path)
      end

      attr_accessor :path, :write_path, :is_managed

      def initialize(path)
        @path = path
        @write_path = path
        @file_exists = File.exist?(path)
        @is_managed = false
      end

      def dirty?
        ini_file.sections.any?(&:dirty?)
      end

      def destroy
        ini_file.sections.each { |s| s.destroy = true }
        save
      end

      def settings
        found = {}
        ini_file.sections.each do |section|
          section.entries
                 .select { |e| e.is_a? Array }
                 .each { |(setting, value)| found["#{section.name}/#{setting}"] = self.class.deserialize_value(value) }
        end
        found
      end

      def get_setting(section, setting)
        store = ini_file.get_section(section)
        return unless store

        self.class.deserialize_value(store[setting])
      end

      def get_section(section, create: false)
        value = ini_file.get_section(section)
        value ||= ini_file.add_section(section) if create

        value
      end

      def remove_setting(section, setting)
        store = ini_file.get_section(section)
        return unless store

        store.entries.delete_if { |(k, _)| k == setting }
        store.mark_dirty
      end

      def set_setting(section, setting, value)
        store = ini_file.get_section(section) || ini_file.add_section(section)
        value = self.class.serialize_value(value)
        store[setting] = value
      end

      def save(clean: true, comment: true, backup: true)
        if backup && @file_exists && !@bak
          bak = "#{path}-#{Time.now.to_i}"
          FileUtils.cp(@path, bak)
          @bak = bak
        end

        cleanup_sections if clean
        ensure_comment if comment

        ini_file.store
        @ini_file = nil
      end

      def revert!
        unless @file_exists
          FileUtils.rm_f(path)
          delete_backup!
          return
        end

        raise 'No backup available' unless @bak

        FileUtils.mv(@bak, @path, force: true)
        @bak = nil
      end

      def delete_backup!
        return unless @bak

        FileUtils.rm(@bak)
        @bak = nil
      end

      def self.deserialize_value(value)
        return if value.nil?
        return true if value == 'true'
        return false if value == 'false'
        return value.to_i if value.match? %r{^[-+]?\d+$}
        return value.to_f if value.match? %r{^[-+]?\d+\.\d+$}
        return JSON.parse(value) if value.strip.start_with? '{'
        return value.split(';').map { |v| deserialize_value(v) }.compact if value.include? ';'

        value
      end

      def self.serialize_value(value)
        return if value.nil?
        return value.to_s if [true, false].include?(value) || value.is_a?(Numeric)
        return value.to_json if value.is_a? Hash
        return serialize_value(value.first) if value.is_a?(Array) && value.size == 1
        return "#{value.map { |v| serialize_value(v) }.join ';'};" if value.is_a? Array

        value.to_s.strip
      end

      private

      def cleanup_sections
        ini_file.sections.each do |section|
          next if section.entries.any? { |e| e.is_a? Array }

          section.destroy = true
          section.mark_dirty
        end
        existing_sections = ini_file.sections.reject { |e| e.destroy? }
        ini_file.sections.each do |section|
          next unless section.entries.any? { |e| e.is_a? Array }

          before = section.entries.dup
          section.entries.delete_if { |e| e.is_a?(String) && e.strip.empty? }
          section.entries << "\n" unless section == existing_sections.last
          section.mark_dirty if before != section.entries
        end
      end

      COMMENT = 'Managed by Puppet'

      def ensure_comment
        return if ini_file.contents.any? { |c| c.is_a?(String) && c.include?(COMMENT) }

        ini_file.contents.unshift("# #{COMMENT}\n\n")
      end

      def ini_file
        @ini_file ||= begin
          file = Puppet::Util::IniConfig::PhysicalFile.new(write_path)
          file.destroy_empty = true
          if path == write_path
            file.read if File.exist? path
          elsif File.exist? path
            data = File.read(path)
            file.send :parse, data
          end
          file
        end
      end
    end
  end
end
