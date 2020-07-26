# Disable shard allocation and perform synced flush
plan example::elasticsearch::restart_node_pre (
  String $target,
  String $es_url = 'http://127.0.0.1:9200',
  Boolean $synced_flush = true,
  Integer $tries = 10,
  Integer $try_sleep = 30,
  Boolean $silent = false,
) {

  # Disable shard allocation
  $shard_alloc_disabled = Integer[1, $tries].any |$try| {
    $res = choria::run_playbook('choria::tasks::run',
      nodes         => [ $target ],
      task          => 'example::query_rest',
      silent        => $silent,
      _catch_errors => true,
      inputs        => {
        url     => "${es_url}/_cluster/settings",
        method  => 'PUT',
        headers => { 'Content-Type' => 'application/json' },
        data    => '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}',
      },
    )

    $out = $res.first.then |$x|{$x['data'].dig('stdout').then |$y|{$y.parsejson}}
    $code = $out.dig('code')
    $acknowledged = $out.dig('body').then |$x|{$x.parsejson}.dig('acknowledged')

    if !$res.results.empty and $code == '200' and $acknowledged {
      true
    } else {
      warning("Unable to disable shard allocation. Retrying... (${try}/${tries})!")
      if $try < $tries {
        reboot::sleep($try_sleep)
      }
      false
    }
  }

  unless $shard_alloc_disabled {
    return false
  }

  # Perform [synced] flush
  $flush_url = $synced_flush ? {
    true  => "${es_url}/_flush/synced",
    false => "${es_url}/_flush",
  }

  $flushed = Integer[1, $tries].any |$try| {
    $res = choria::run_playbook('choria::tasks::run',
      nodes         => [ $target ],
      task          => 'example::query_rest',
      silent        => $silent,
      _catch_errors => true,
      inputs        => {
        url    => $flush_url,
        method => 'POST',
      },
    )

    $out = $res.first['data'].dig('stdout').then |$x|{$x.parsejson}
    $code = $out.dig('code')
    $body = $out.dig('body').then |$x|{$x.parsejson}

    # Ensure flushed
    $failed_shards = $body.reduce(0) |$memo, $shard| {
      $f = $shard[1]['failed']
      if $f > 0 {
        warning("Failed to flush shard ${shard[0]}!")
        $memo + $f
      } else {
        $memo
      }
    }

    if !$res.results.empty and $code == '200' and $failed_shards == 0 {
      true
    } else {
      warning("Unable to disable shard allocation. Retrying... (${try}/${tries})!")
      if $try < $tries {
        reboot::sleep($try_sleep)
      }
      false
    }
  }

  unless $flushed {
    return false
  }

  return true
}
