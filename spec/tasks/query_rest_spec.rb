require_relative File.join(__dir__, '..', '..', 'tasks', 'query_rest.rb')
require 'webmock/rspec'

describe 'QueryRest' do
  let(:task) { QueryRest.new }
  let(:dest) do
    {
      host: '127.0.0.1',
      port: 8200,
    }
  end
  let(:sample_headers) do
    {
      'Accept' => '*/*',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Host' => "#{dest[:host]}:#{dest[:port]}",
      'User-Agent' => 'example::query_rest',
    }
  end
  let(:api_url) { "http://#{dest[:host]}:#{dest[:port]}/v1" }

  WebMock.disable_net_connect!

  context 'with url and no method)' do
    let(:params) { { url: "#{api_url}/pki/roles/foo" } }

    it 'returns response' do
      body = {
        data: {
          allow_any_name: false,
        },
      }
      out = {
        code: '200',
        message: '',
        body: body.to_json,
        headers: {},
      }

      stub_request(:get, params[:url]).with(
        headers: sample_headers,
      ).to_return(
        status: 200,
        body: '{"data":{"allow_any_name":false}}',
      )
      expect(task.task(params)).to eq(out.to_json)
    end
  end

  context 'with url and LIST method' do
    let(:params) { { url: "#{api_url}/pki/roles/foo", method: 'LIST' } }

    it 'returns response' do
      body = {
        auth: nil,
        data: {
          keys: ['dev', 'prod'],
        },
        lease_duration: 2_764_800,
      }
      out = {
        code: '200',
        message: '',
        body: body.to_json,
        headers: {},
      }

      stub_request(:list, params[:url]).with(
        headers: sample_headers,
      ).to_return(
        status: 200,
        body: '{"auth":null,"data":{"keys":["dev","prod"]},"lease_duration":2764800}',
      )
      expect(task.task(params)).to eq(out.to_json)
    end
  end

  context 'with url and DELETE method' do
    let(:params) do
      {
        url: "#{api_url}/pki/roles/foo",
        method: 'DELETE',
        headers: {
          'X-Vault-Token' => 'abcdefghijklmn',
        },
      }
    end

    it 'returns response' do
      out = {
        code: '200',
        message: '',
        body: '',
        headers: {},
      }

      stub_request(:delete, params[:url]).with(
        headers: sample_headers.merge(params[:headers]),
      ).to_return(
        status: 200,
        body: '',
      )
      expect(task.task(params)).to eq(out.to_json)
    end
  end

  context 'with url and POST method' do
    let(:params) do
      {
        url: "#{api_url}/pki/roles/foo",
        method: 'POST',
        headers: {
          'X-Vault-Token' => 'abcdefghijklmn',
          'Content-Type' => 'application/json',
        },
        data: '{"allowed_domains":["example.com"],"allow_subdomains":true}',
      }
    end

    it 'returns response' do
      out = {
        code: '200',
        message: '',
        body: { status: 'OK' }.to_json,
        headers: {
          'content-type' => ['application/json'],
        },
      }

      stub_request(:post, params[:url]).with(
        headers: sample_headers.merge(params[:headers]),
      ).to_return(
        status: 200,
        body: '{"status":"OK"}',
        headers: {
          'Content-Type' => 'application/json',
        },
      )
      expect(task.task(params)).to eq(out.to_json)
    end
  end

  context 'with url and PUT method' do
    let(:params) do
      {
        url: "#{api_url}/pki/roles/foo",
        method: 'PUT',
        headers: {
          'X-Vault-Token' => 'abcdefghijklmn',
        },
        data: '{"allowed_domains":["example.com"],"allow_subdomains":true}',
      }
    end

    it 'returns response' do
      out = {
        code: '200',
        message: '',
        body: { status: 'OK' }.to_json,
        headers: {},
      }

      stub_request(:put, params[:url]).with(
        headers: sample_headers.merge(params[:headers]),
      ).to_return(
        status: 200,
        body: '{"status":"OK"}',
      )
      expect(task.task(params)).to eq(out.to_json)
    end
  end
end
