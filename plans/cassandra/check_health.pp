# Read cassandra metrics from nodes and wait for good cluster state
# Using https://github.com/instaclustr/cassandra-exporter exporter
plan example::cassandra::check_health (
  Array[String] $targets,
  String $cluster_name,
  Integer $tries = 10,
  Integer $try_sleep = 60,
  Boolean $silent = false,
  String $exporter_url = 'http://127.0.0.1:9500/metrics',
) {
  $health_metric = 'cassandra_endpoint_active'

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

    # Every server return every node's stats (so we have NxN results)
    $good_number = $targets.size * $targets.size

    if ($res.results.empty) {
      $good_servers = 0
    } else {
      $good_servers = $res.reduce(0) |$memo, $r| {
        $out = $r['data']['stdout'].parsejson

        # Node's good servers
        $ngs = $out.dig('metrics').then |$x| {
          $x.reduce(0) |$mm, $m| {
            # XXX Check for cluster name?
            $m[1] ? {
              default => ($mm + ceiling(Float($m[1]))),
              Undef   => $mm,
            }
          }
        }

        $ngs ? {
          default => ($memo + $ngs),
          Undef   => $memo,
        }
      }
    }

    if (!$res.results.empty) and $good_servers == $good_number {
      return true
    }

    # if there is any error during task execution no results will be returned at all
    if $res.results.empty {
      warning("Failed to read cluster metrics. Retrying... (${try}/${tries})")
    } elsif $good_servers != $good_number {
      warning("Cluster is not OK (${good_servers}/${good_number}). Retrying... (${try}/${tries})!")
    }

    if $try < $tries {
      reboot::sleep($try_sleep)
    }
  }
  return false
}
