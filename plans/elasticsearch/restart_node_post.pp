# Enable shard allocation
plan example::elasticsearch::restart_node_post (
  String $target,
  String $es_url = 'http://127.0.0.1:9200',
  Integer $tries = 10,
  Integer $try_sleep = 30,
  Boolean $silent = false,
) {

  # Enable shard allocation
  Integer[1, $tries].any |$try| {
    $res = choria::run_playbook('choria::tasks::run',
      nodes         => [ $target ],
      task          => 'example::query_rest',
      silent        => $silent,
      _catch_errors => true,
      inputs        => {
        url     => "${es_url}/_cluster/settings",
        method  => 'PUT',
        headers => { 'Content-Type' => 'application/json' },
        data    => '{"persistent":{"cluster.routing.allocation.enable":null}}',
      },
    )

    $out = $res.first.then |$x|{$x['data'].dig('stdout').then |$y|{$y.parsejson}}
    $code = $out.dig('code')
    $acknowledged = $out.dig('body').then |$x|{$x.parsejson}.dig('acknowledged')

    if !$res.results.empty and $code == '200' and $acknowledged {
      true
    } else {
      warning("Unable to enable shard allocation. Retrying... (${try}/${tries})!")
      if $try < $tries {
        reboot::sleep($try_sleep)
      }
      false
    }
  }
  # It will return result of any() function
}
