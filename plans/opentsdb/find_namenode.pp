# Get active/passive namenode: localhost:9070/metrics | grep ^namenode_state (1 = active)
plan example::opentsdb::find_namenode (
  Array[String] $targets,
  Boolean $silent = false,
  String $exporter_url = 'http://127.0.0.1:9070/metrics',
) {
  $namenode_metric = 'namenode_state'

  $res = choria::task(
    action     => 'query.exporter',
    nodes      => $targets,
    silent     => $silent,
    fail_ok    => true,
    properties => {
      url     => $exporter_url,
      metrics => [ $namenode_metric ],
    },
  )

  # Find namenode
  $namenode = $res.reduce([]) |$memo, $r| {
    $nn = $r['data'].dig('metrics', $namenode_metric)
    $nn ? {
      '1'     => $memo + $r.host,
      default => $memo,
    }
  }

  if ($namenode.size != 1) {
    fail("There must be exactly 1 namenode node in cluster! Nodes found: ${namenode.join(',')}")
  }

  $namenode
}
