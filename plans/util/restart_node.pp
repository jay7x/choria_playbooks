# Restart single node and ensure service is running after
plan example::util::restart_node (
  String $target,
  Array[String] $services = [],
  Boolean $silent = true,
  Boolean $reboot = false,
  Boolean $noop = false,
) {
  info("=== Working on ${target} (services: [${services.join(',')}], noop: ${noop}, reboot: ${reboot})")

  # reboot node (optional cmdline switch) (bolt task reboot)
  if $reboot {
    info('== Rebooting node...')
    unless $noop {
      $res = choria::run_playbook('choria::tasks::run',
        nodes  => [ $target ],
        task   => 'reboot',
        silent => $silent,
        inputs => {
          timeout => 10,
          message => "Reboot is requested from ${facts['choria']['playbook']}",
        },
      )
    }

    # Wait node to go down
    info('== Waiting for node to go down...')
    Integer[1, 18].each |$try| {
      unless $noop {
        $status = choria::task(
          action    => 'rpcutil.ping',
          nodes     => [ $target ],
          pre_sleep => 10,
          tries     => 1,
          silent    => $silent,
          fail_ok   => true,
        )
        if $status.ok_set.empty {
          break()
        }
      } else {
        info('=== (noop)')
        break()
      }
    }

    $pre_sleep = $noop ? {
      true  => 0,
      false => 20,
    }
    # Wait node to return
    info('== Waiting for node to return...')
    choria::task(
      action    => 'rpcutil.ping',
      nodes     => [ $target ],
      pre_sleep => $pre_sleep,
      tries     => 18,
      try_sleep => 10,
      silent    => $silent,
    )

  } else { # no reboot, just restart the service

    # Stop services in reverse order
    $services.reverse_each |$service_name| {

      if $noop {
        info("== Stopping ${service_name}... (noop)")
      } else {

        # stop service (service.stop)
        info("== Stopping ${service_name}...")
        choria::task(
          action     => 'service.stop',
          nodes      => [ $target ],
          silent     => $silent,
          properties => {
            service => $service_name,
          },
        )

        # ensure service is stopped (service.status)
        info("== Checking ${service_name} is stopped...")
        choria::task(
          action     => 'service.status',
          nodes      => [ $target ],
          assert     => 'status=stopped',
          pre_sleep  => 0,
          tries      => 4,
          try_sleep  => 30,
          silent     => $silent,
          properties => {
            service => $service_name,
          },
        )

      } # if $noop
    } # $services
  } # if $reboot

  $services.each |$service_name| {

    unless $reboot {
      if $noop {
        info("== Starting ${service_name}... (noop)")
      } else {
        # start service (service.start)
        info("== Starting ${service_name}...")
        choria::task(
          action     => 'service.start',
          nodes      => [ $target ],
          silent     => $silent,
          properties => {
            service => $service_name,
          },
        )
      }
    }

    # ensure service is running (service.status)
    info("== Checking ${service_name} is started...")
    choria::task(
      action     => 'service.status',
      nodes      => [ $target ],
      assert     => 'status=running',
      pre_sleep  => 0,
      tries      => 10,
      try_sleep  => 30,
      silent     => $silent,
      properties => {
        service => $service_name,
      },
    )
  }
}
