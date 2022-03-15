# frozen_string_literal: true

require 'puppet/util/inifile'

module PuppetX # rubocop:disable Style/ClassAndModuleChildren
  module Networkmanager # rubocop:disable Style/ClassAndModuleChildren
    # Networkmanager connection wrapper
    #
    # To reduce to-file flushes
    class Connection
      def self.[](path)
        (@connections ||= {})[path] ||= new(path)
      end

      attr_accessor :path

      def initialize(path)
        @path = path
      end

      def dirty?
        ini_file.sections.any?(&:dirty?)
      end

      def destroy
        ini_file.sections.each { |s| s.destroy = true }
        flush
      end

      def settings
        found = {}
        ini_file.sections.each do |section|
          section.entries
                 .select { |e| e.is_a? Array }
                 .each { |(setting, value)| found["#{section.name}/#{setting}"] = value }
        end
        found
      end

      def get_setting(section, setting)
        store = ini_file.get_section(section)
        return unless store

        store[setting]
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
        store[setting] = value
      end

      def flush(clean: true, comment: true)
        cleanup_sections if clean
        ensure_comment if comment
        ini_file.store
        @ini_file = nil
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
          file = Puppet::Util::IniConfig::PhysicalFile.new(path)
          file.destroy_empty = true
          file.read if File.exist? path
          file
        end
      end
    end
  end
end
