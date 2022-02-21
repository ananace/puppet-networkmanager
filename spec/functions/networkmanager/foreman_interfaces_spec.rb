# frozen_string_literal: true

require 'spec_helper'

CONTEXTS = begin
  data = {}

  Dir[File.join('spec', 'fixtures', 'foreman_interfaces', '*.yml')].each do |file|
    data[File.basename(file).gsub('.yml', '')] = Psych.load(open(file).read)
  end

  data
end

describe 'networkmanager::munge_foreman_interfaces' do
  it { is_expected.not_to eq(nil) }

  CONTEXTS.each do |name, data|
    context "with #{name}" do
      before(:each) do
        expect(scope).to receive(:[]).with('facts').and_return(data['facts'])
        expect(scope).to receive(:[]).with('foreman_interfaces').and_return(data['foreman_interfaces'])
      end

      it { is_expected.to run.and_return(data['result']) }
    end
  end
end

