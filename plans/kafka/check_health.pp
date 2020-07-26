# Read kafka metrics from nodes and wait for 0 underreplicated partitions
# Using jmx_exporter
# kafka_server_replicamanager_underreplicatedpartitions 0
plan example::kafka::check_health (
  Array[String] $targets,
  Integer $tries = 10,
  Integer $try_sleep = 60,
  Boolean $silent = false,
  String $exporter_url = 'http://127.0.0.1:9080',
) {
  $health_metric = 'kafka_server_replicamanager_underreplicatedpartitions'

  Integer[1, $tries].each |$try| {
    # Get cluster metrics
    $res = choria::run_playbook('choria::tasks::run',
      nodes         => $targets,
      task          => 'example::query_exporter',
      silent        => $silent,
      _catch_errors => true,
      inputs        => {
        url     => $exporter_url,
        metrics => [ $health_metric ],
      },
    )

    $urp = $res.reduce(0) |$memo, $r| {
      $out = $r['data']['stdout'].parsejson
      $v = $out.dig('metrics', $health_metric)
      # If there is no such metric assume there is at least 1 underreplicated partition
      if $v {
        $memo + ceiling(Float($v))
      } else {
        $memo + 1
      }
    }

    if (!$res.results.empty) and $urp == 0 {
      return true
    }

    # if there is any error during task execution no results will be returned at all
    if $res.results.empty {
      warning("Failed to read cluster metrics. Retrying... (${try}/${tries})")
    }

    if $urp > 0 {
      warning("Cluster still have underreplicated partitions (${urp}). Retrying... (${try}/${tries})!")
    }

    if $try < $tries {
      reboot::sleep($try_sleep)
    }
  }
  return false
}
