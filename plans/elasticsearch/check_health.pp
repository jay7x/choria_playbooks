# Read elasticsearch metrics from nodes and wait for green cluster state
# Using https://github.com/justwatchcom/elasticsearch_exporter exporter
# elasticsearch_cluster_health_status{cluster="${cluster_name}",color="green"} 1
plan example::elasticsearch::check_health (
  Array[String] $targets,
  String $cluster_name,
  Integer $tries = 10,
  Integer $try_sleep = 60,
  Boolean $silent = false,
  String $exporter_url = 'http://127.0.0.1:9108/metrics',
) {
  $health_metric = "elasticsearch_cluster_health_status{cluster=\"${cluster_name}\",color=\"green\"}"

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

    $good_servers = $res.reduce(0) |$memo, $r| {
      $out = $r['data']['stdout'].parsejson
      $v = $out['metrics'][$health_metric]
      # If there is no such metric assume cluster is not healty
      if $v {
        $memo + Integer($v)
      } else {
        $memo
      }
    }

    if (!$res.results.empty) and $good_servers == $targets.size {
      return true
    }

    # if there is any error during task execution no results will be returned at all
    if $res.results.empty {
      warning("Failed to read cluster metrics. Retrying... (${try}/${tries})")
    }

    if $good_servers != $targets.size {
      warning("Cluster is not green (${good_servers}/${targets.size}). Retrying... (${try}/${tries})!")
    }

    if $try < $tries {
      reboot::sleep($try_sleep)
    }
  }
  return false
}
