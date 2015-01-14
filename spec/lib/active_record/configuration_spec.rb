require 'spec_helper'
require 'rom/rails/active_record/configuration'
require 'addressable/uri'

describe ROM::Rails::ActiveRecord::Configuration do
  let(:root) { Pathname.new('/path/to/app') }

  def uri_for(config)
    result = read(config)
    result.is_a?(Hash) ? result[:uri] : result
  end

  def read(config)
    result = described_class.build(config.merge(root: root))
  end

  def parse(uri)
    Addressable::URI.parse(uri.gsub(/^jdbc:/, ''))
  end

  it 'raises an error without specifying a database'

  context 'with postgresql adapter' do
    it 'rewrites the scheme' do
      uri = uri_for(adapter: 'postgresql', database: 'test')
      expect(parse(uri).scheme).to eql('postgres')
    end

    it 'does not use jdbc even on jruby' do
      uri = uri_for(adapter: 'postgresql', database: 'test')
      expect(uri).to_not start_with('jdbc:')
    end

    it 'only includes username if no password is given' do
      uri = uri_for(
        adapter: 'postgresql',
        host: 'example.com',
        database: 'test',
        username: 'user'
      )

      expect(parse(uri).userinfo).to eql('user')
    end

    it 'includes username and password if both are given' do
      uri = uri_for(
        adapter: 'postgresql',
        database: 'test',
        username: 'user',
        password: 'password',
        host: 'example.com'
      )

      expect(parse(uri).userinfo).to eql('user:password')
    end

    it 'omits userinfo if neither username nor password are given' do
      uri = uri_for(adapter: 'postgresql', database: 'test')
      expect(parse(uri).userinfo).to be_nil
    end

    it 'properly handles configuration without a host' do
      uri = uri_for(adapter: 'postgresql', database: 'test')
      expect(uri).to eql('postgres:///test')
    end

    it 'properly handles authentication even without a host' do
      uri = parse(uri_for(
        adapter: 'postgresql',
        database: 'test',
        username: 'user',
        password: 'pass'
      ))

      expect(uri.hostname).to be_empty
      expect(uri.userinfo).to be_nil
      expect(uri.query_values).to eq('username' => 'user', 'password' => 'pass')
    end

    it 'properly handles authentication even without host and database' do
      uri = parse(uri_for(
        adapter: 'postgresql',
        username: 'user',
        password: 'pass'
      ))

      expect(uri.hostname).to be_empty
      expect(uri.path).to be_empty
      expect(uri.userinfo).to be_nil
      expect(uri.query_values).to eq('username' => 'user', 'password' => 'pass')
    end
  end

  context 'with mysql adapter' do
    it 'sets default password to an empty string' do
      uri = uri_for(adapter: 'mysql', database: 'test', username: 'root', host: 'example.com')
      expect(parse(uri).userinfo).to eql('root:')
    end

    it 'uses jdbc only on jruby' do
      uri = uri_for(adapter: 'mysql', database: 'test')
      expect(uri.starts_with?('jdbc:')).to be(RUBY_ENGINE == 'jruby')
    end
  end

  context 'with sqlite3 adapter' do
    let(:database) { Pathname.new('db/development.sqlite3') }
    let(:config) { {adapter: adapter, database: database} }

    it 'rewrites the scheme' do
      uri = uri_for(adapter: 'sqlite3', database: database)
      expect(parse(uri).scheme).to eql('sqlite')
    end

    it 'uses jdbc only on jruby' do
      uri = uri_for(adapter: 'sqlite3', database: database)
      expect(uri.starts_with?('jdbc:')).to be(RUBY_ENGINE == 'jruby')
    end

    it 'expands the path' do
      uri = uri_for(adapter: 'sqlite3', database: database)
      expect(parse(uri).path).to eql(root.join(database).to_s)
    end
  end
end
