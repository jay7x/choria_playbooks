# Check OpenTSDB cluser health
# Calling REST Stats API directly
plan example::opentsdb::check_health (
  Array[String] $targets,
  Integer $tries = 10,
  Integer $try_sleep = 60,
  Boolean $silent = false,
  String $health_check_url = 'http://127.0.0.1:4242/api/stats',
) {
  Integer[1, $tries].each |$try| {
    # Get cluster stats
    $res = choria::task(
      action     => 'query.rest',
      nodes      => $targets,
      silent     => true,   # it's too noisy otherwise
      fail_ok    => true,
      properties => {
        url     => $health_check_url,
        method  => 'GET',
        headers => {},
        data    => '',
      },
    )

    # Just check we have valid JSON reply from every node
    $ok = $res.all |$r| {
      $parsed = $r['data'].dig('body').then |$x| { parsejson($x, 'false') }
      $parsed ? {
        undef   => false,
        'false' => false,
        default => true,
      }
    }

    if $ok {
      return true
    }

    warning("Cluster is not OK. Retrying... (${try}/${tries})!")

    if $try < $tries {
      reboot::sleep($try_sleep)
    }
  }
  return false
}
