#!/usr/bin/env ruby

require 'terminal-table/import'


  # returns a hash of stats. cgroup names with their elapsed cpu time/mem usage in bytes
  def read_cgroup_stats
    cpuacct_dir = '/sys/fs/cgroup/'

    @last_cpu_reading ||= {}
    readings = Hash.new {|h,k| h[k] = {}  }

    Dir["#{cpuacct_dir}/cpuacct/**/*", "#{cpuacct_dir}/memory/**/*"].each do |fname|
      f = fname.sub /^#{cpuacct_dir}\/(cpuacct|memory)/, ''

      begin
        if f.sub! /\/cpuacct.usage$/, ''
          cpu_reading = File.read(fname).to_f / 1E9
          readings[f]['cpu'] = (cpu_reading - (@last_cpu_reading[f] || 0))
          @last_cpu_reading[f] = cpu_reading
        elsif f.sub! /\/memory.usage_in_bytes$/, ''
          readings[f]['mem'] = File.read(fname).to_i.div(1048576)
        elsif f.sub! /\/tasks$/, ''
          readings[f]['tasks'] = File.read(fname).lines.count
        end
      rescue
        readings.delete 'f' if readings['f']
      end
    end
    readings
  end


["INT","TERM", "TRAP", "USR1", "HUP"].each {|sig| Signal.trap(sig) { exit } }

seconds = 3
oldtimestamp = Time.now.to_f
read_cgroup_stats
sleep seconds

loop do
  puts "\e[H\e[2J"
  stats = read_cgroup_stats
  timestamp = Time.now.to_f
  groups = stats.keys.select {|g| stats[g]['tasks'] > 0}.sort
  puts table(['Group                    ', 'Tasks', 'Mem(MB)', 'CPU%'],
       *groups.map {|g| [
         (g == '' ? 'ALL' : g),
         '% 7d' % stats[g]['tasks'],
         '% 7d' % stats[g]['mem'],
         '% 6.01f%%' % (100 * stats[g]['cpu'] / (timestamp - oldtimestamp))
       ]}
  )
  oldtimestamp = timestamp
  sleep seconds
end
