require_relative File.join(__dir__, '..', '..', 'tasks', 'query_exporter.rb')

describe 'QueryExporter' do
  let(:task) { QueryExporter.new }
  let(:sample_content) do
    [
      "# HELP go_gc_duration_seconds A summary of the GC invocation durations.\n",
      "# TYPE go_gc_duration_seconds summary\n",
      "  \n",
      "go_gc_duration_seconds{a=\"b\",quantile=\"0\"} 7.6e-06\n",
      "go_gc_duration_seconds{a=\"b\",quantile=\"0.25\"} 4.31e-05\n",
      "go_gc_duration_seconds{a=\"b\",quantile=\"0.5\"} 8.6001e-05\n",
      "go_gc_duration_seconds{a=\"b\",quantile=\"0.75\"} 0.000145801\n",
      "go_gc_duration_seconds{a=\"b\",quantile=\"1\"} 0.003476917\n",
      "go_gc_duration_seconds_sum 22.379136427\n",
      "go_gc_duration_seconds_count 165860\n",
    ]
  end

  context 'with url but no metrics' do
    let(:params) do
      {
        url: 'http://127.0.0.1:9100/metrics',
      }
    end

    it 'returns all metrics' do
      out = {
        metrics: {
          'go_gc_duration_seconds{a="b",quantile="0"}' => '7.6e-06',
          'go_gc_duration_seconds{a="b",quantile="0.25"}' => '4.31e-05',
          'go_gc_duration_seconds{a="b",quantile="0.5"}' => '8.6001e-05',
          'go_gc_duration_seconds{a="b",quantile="0.75"}' => '0.000145801',
          'go_gc_duration_seconds{a="b",quantile="1"}' => '0.003476917',
          'go_gc_duration_seconds_sum' => '22.379136427',
          'go_gc_duration_seconds_count' => '165860',
        },
      }

      allow(task).to receive(:fetch_metrics).and_return(sample_content)
      expect(task.task(params)).to eq(out.to_json)
    end
  end

  context 'with url and empty metrics array' do
    let(:params) do
      {
        url: 'http://127.0.0.1:9100/metrics',
        metrics: [],
      }
    end

    it 'returns all metrics' do
      out = {
        metrics: {
          'go_gc_duration_seconds{a="b",quantile="0"}' => '7.6e-06',
          'go_gc_duration_seconds{a="b",quantile="0.25"}' => '4.31e-05',
          'go_gc_duration_seconds{a="b",quantile="0.5"}' => '8.6001e-05',
          'go_gc_duration_seconds{a="b",quantile="0.75"}' => '0.000145801',
          'go_gc_duration_seconds{a="b",quantile="1"}' => '0.003476917',
          'go_gc_duration_seconds_sum' => '22.379136427',
          'go_gc_duration_seconds_count' => '165860',
        },
      }

      allow(task).to receive(:fetch_metrics).and_return(sample_content)
      expect(task.task(params)).to eq(out.to_json)
    end
  end

  context 'with url and metrics(names only)' do
    let(:params) do
      {
        url: 'http://127.0.0.1:9100/metrics',
        metrics: [
          'go_gc_duration_seconds',
          'go_gc_duration_seconds_count',
        ],
      }
    end

    it 'returns metrics found' do
      out = {
        metrics: {
          'go_gc_duration_seconds{a="b",quantile="0"}' => '7.6e-06',
          'go_gc_duration_seconds{a="b",quantile="0.25"}' => '4.31e-05',
          'go_gc_duration_seconds{a="b",quantile="0.5"}' => '8.6001e-05',
          'go_gc_duration_seconds{a="b",quantile="0.75"}' => '0.000145801',
          'go_gc_duration_seconds{a="b",quantile="1"}' => '0.003476917',
          'go_gc_duration_seconds_count' => '165860',
        },
      }

      allow(task).to receive(:fetch_metrics).and_return(sample_content)
      expect(task.task(params)).to eq(out.to_json)
    end
  end

  context 'with url and metrics(with labels)' do
    let(:params) do
      {
        url: 'http://127.0.0.1:9100/metrics',
        metrics: [
          'go_gc_duration_seconds{a="b",quantile="1"}',
          'go_gc_duration_seconds_count',
        ],
      }
    end

    it 'returns metrics found' do
      out = {
        metrics: {
          'go_gc_duration_seconds{a="b",quantile="1"}' => '0.003476917',
          'go_gc_duration_seconds_count' => '165860',
        },
      }

      allow(task).to receive(:fetch_metrics).and_return(sample_content)
      expect(task.task(params)).to eq(out.to_json)
    end
  end

  context 'with url and metrics(with wrong labels)' do
    let(:params) do
      {
        url: 'http://127.0.0.1:9100/metrics',
        metrics: [
          'go_gc_duration_seconds{quantile="1",a="b"}',
          'go_gc_duration_seconds_count',
        ],
      }
    end

    it 'returns metrics found' do
      out = {
        metrics: {
          'go_gc_duration_seconds_count' => '165860',
        },
      }

      allow(task).to receive(:fetch_metrics).and_return(sample_content)
      expect(task.task(params)).to eq(out.to_json)
    end
  end
end
